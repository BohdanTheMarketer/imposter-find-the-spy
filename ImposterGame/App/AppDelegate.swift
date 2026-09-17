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
        #endif
        // Copies the token to the clipboard on-device so it can be pasted into Notes/Messages
        // and grabbed for Firebase Console's "send to device" test flow without a Mac connection.
        UIPasteboard.general.string = fcmToken
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
