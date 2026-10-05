import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize Amplitude Analytics + Session Replay once, on-device, at launch.
        AmplitudeManager.start()

        // OneSignal push + in-app messaging (all SDK calls live in OneSignalManager).
        OneSignalManager.shared.initialize(launchOptions: launchOptions)

        // One-time Apple Search Ads attribution fetch (free, on-device, no MMP).
        SearchAdsAttributionService.fetchAttributionIfNeeded()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        PushNotificationService.migratePromptVersionIfNeeded()

        // Every install subscribes to this topic, so you can send a test push from
        // Firebase Console → Messaging → New campaign → target "Topic" → "all_devices",
        // with no device token needed at all.
        Messaging.messaging().subscribe(toTopic: "all_devices")

        Task {
            await PushNotificationService.registerForRemoteNotificationsIfAuthorized()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        #if DEBUG
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[APNs] device token registered (\(token.prefix(16))…)")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[APNs] registration failed: \(error.localizedDescription)")
        #endif
        Crashlytics.crashlytics().record(error: error)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        #if DEBUG
        print("[FCM] registration token: \(fcmToken)")
        // Copies the token to the clipboard on-device so it can be pasted into Notes/Messages
        // and grabbed for Firebase Console's "send to device" test flow without a Mac connection.
        // Debug-only: in production this would overwrite the user's clipboard on every token refresh.
        UIPasteboard.general.string = fcmToken
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
        completionHandler([.banner, .badge, .sound])
    }

    // Explicit tap handler: Firebase's swizzling isn't reliable behind SwiftUI's
    // @UIApplicationDelegateAdaptor, and without this call `notification_open` never reaches
    // Analytics, so campaign "Opens" stay at zero.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Messaging.messaging().appDidReceiveMessage(userInfo)
        // Mirrors the open to Amplitude, which doesn't see Firebase's notification_open.
        AnalyticsService.logEvent("push_opened", parameters: [
            "campaign_id": userInfo["google.c.a.c_id"] as? String ?? "",
            "campaign_name": userInfo["google.c.a.c_l"] as? String ?? ""
        ])
        completionHandler()
    }
}
