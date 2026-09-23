import Foundation
import OneSignalFramework
import UIKit

/// Single entry point for every OneSignal SDK call — nothing else in the app imports OneSignalFramework.
///
/// Push permission is still requested by `PushNotificationService` on the Categories screen
/// (existing product flow). OneSignal picks up the resulting authorization status automatically
/// when the app returns to the foreground after the system prompt.
final class OneSignalManager {
    static let shared = OneSignalManager()

    #if DEBUG
    private var subscriptionObserver: DebugPushSubscriptionObserver?
    #endif

    private init() {}

    func initialize(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if DEBUG
        OneSignal.Debug.setLogLevel(.LL_INFO)
        #endif
        OneSignal.initialize(AppConstants.oneSignalAppId, withLaunchOptions: launchOptions)

        #if DEBUG
        startDebugSubscriptionLogging()
        #endif
    }

    // MARK: - Identity

    func login(externalId: String) {
        OneSignal.login(externalId)
    }

    func logout() {
        OneSignal.logout()
    }

    // MARK: - Tags

    func setTag(key: String, value: String) {
        OneSignal.User.addTag(key: key, value: value)
    }

    func removeTag(key: String) {
        OneSignal.User.removeTag(key)
    }

    // MARK: - Permission

    /// Prefer `PushNotificationService.requestPermission(context:)` in app flows; this exists for QA / future use.
    func requestPermission(completion: @escaping (Bool) -> Void) {
        OneSignal.Notifications.requestPermission({ accepted in
            completion(accepted)
        }, fallbackToSettings: false)
    }

    var pushSubscriptionId: String? {
        OneSignal.User.pushSubscription.id
    }

    // MARK: - Debug verification

    #if DEBUG
    /// Logs the OneSignal push subscription ID once the device is registered with OneSignal's servers,
    /// so the integration can be verified from the Xcode console (Dashboard → Audience → Subscriptions).
    private func startDebugSubscriptionLogging() {
        let observer = DebugPushSubscriptionObserver()
        subscriptionObserver = observer // OneSignal holds observers weakly.
        OneSignal.User.pushSubscription.addObserver(observer)
        observer.evaluate(OneSignal.User.pushSubscription.id)
    }
    #endif
}

#if DEBUG
private final class DebugPushSubscriptionObserver: NSObject, OSPushSubscriptionObserver {
    private var hasLogged = false

    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        evaluate(state.current.id)
    }

    /// A real server-assigned ID is non-empty and not the SDK's `local-` placeholder.
    func evaluate(_ subscriptionId: String?) {
        guard let id = subscriptionId, !id.isEmpty, !id.hasPrefix("local-"), !hasLogged else { return }
        hasLogged = true
        print("[OneSignal] ✅ integration complete — push subscription ID: \(id)")
    }
}
#endif
