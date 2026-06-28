import Foundation
import UIKit
import UserNotifications

/// Requests the system push permission dialog on Categories when status is still `.notDetermined`.
enum PushNotificationService {
    private static let hasRequestedPromptKey = "hasShownPushPermissionPrompt"
    private static let lastPromptAppVersionKey = "pushPromptLastShownAppVersion"
    private static let lastPromptContextKey = "pushPromptLastAnalyticsContext"

    static var hasRequestedPushPermission: Bool {
        UserDefaults.standard.bool(forKey: hasRequestedPromptKey)
    }

    /// Backfills version metadata for installs that requested permission before version tracking existed.
    static func migratePromptVersionIfNeeded() {
        guard hasRequestedPushPermission else { return }
        guard UserDefaults.standard.string(forKey: lastPromptAppVersionKey) == nil else { return }
        UserDefaults.standard.set(currentAppVersion, forKey: lastPromptAppVersionKey)
    }

    static func permissionAnalyticsContext() -> String {
        if !hasRequestedPushPermission {
            return "categories_first_visit"
        }
        if didAppVersionChangeSinceLastRequest() {
            return "app_update"
        }
        return "categories_first_visit"
    }

    static func markPermissionRequestAttempted(context: String) {
        UserDefaults.standard.set(true, forKey: hasRequestedPromptKey)
        UserDefaults.standard.set(currentAppVersion, forKey: lastPromptAppVersionKey)
        UserDefaults.standard.set(context, forKey: lastPromptContextKey)
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func shouldRequestPermissionOnCategories() async -> Bool {
        let status = await authorizationStatus()
        guard status == .notDetermined else { return false }
        if !hasRequestedPushPermission { return true }
        return didAppVersionChangeSinceLastRequest()
    }

    static func logPromptShown(context: String) {
        AnalyticsService.logEvent("push_permission_prompt_shown", parameters: [
            "context": context
        ])
    }

    static func logPermissionResult(context: String, status: UNAuthorizationStatus) {
        AnalyticsService.logEvent("push_permission_result", parameters: [
            "context": context,
            "result": analyticsValue(for: status)
        ])
    }

    @discardableResult
    static func requestPermission(context: String) async -> UNAuthorizationStatus {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            let status = await authorizationStatus()
            logPermissionResult(context: context, status: status)

            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return status
        } catch {
            let status = await authorizationStatus()
            logPermissionResult(context: context, status: status)
            return status
        }
    }

    static func registerForRemoteNotificationsIfAuthorized() async {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private static func didAppVersionChangeSinceLastRequest() -> Bool {
        guard hasRequestedPushPermission else { return false }
        guard let lastVersion = UserDefaults.standard.string(forKey: lastPromptAppVersionKey) else {
            return false
        }
        return lastVersion != currentAppVersion
    }

    private static func analyticsValue(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .provisional: return "provisional"
        case .notDetermined: return "not_determined"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    #if DEBUG
    static func resetForQA() {
        UserDefaults.standard.removeObject(forKey: hasRequestedPromptKey)
        UserDefaults.standard.removeObject(forKey: lastPromptAppVersionKey)
        UserDefaults.standard.removeObject(forKey: lastPromptContextKey)
    }
    #endif
}
