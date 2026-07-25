import AmplitudeSwift
#if canImport(AmplitudeSwiftSessionReplayPlugin)
import AmplitudeSwiftSessionReplayPlugin
#endif

/// Single entry point for Amplitude Analytics + Session Replay.
///
/// `shared` is a lazy `static let`, so the Amplitude client is created
/// exactly once for the lifetime of the process no matter how many times
/// it's accessed. Everything here runs on-device (client-side) at runtime.
enum AmplitudeManager {
    /// Amplitude project API key.
    private static let apiKey = "54fd41a7c95ca0c63318cd87f872da83"

    /// The shared Amplitude client — initialized once.
    static let shared: Amplitude = {
        let amplitude = Amplitude(configuration: Configuration(
            apiKey: apiKey,
            // Autocapture sessions, app lifecycles, screen views, network requests,
            // and element interactions (taps) — covers key user interactions.
            autocapture: [.sessions, .appLifecycles, .screenViews, .networkTracking, .elementInteractions]
        ))

        #if canImport(AmplitudeSwiftSessionReplayPlugin)
        // Session Replay (iOS only) at full sample rate.
        amplitude.add(plugin: AmplitudeSwiftSessionReplayPlugin(sampleRate: 1.0))
        #endif

        return amplitude
    }()

    /// Ensures the client is created. Safe to call multiple times; the
    /// underlying `Amplitude` instance is still only initialized once.
    static func start() {
        _ = shared
    }

    /// Tracks a custom event with optional properties.
    static func track(_ eventType: String, properties: [String: Any]? = nil) {
        shared.track(eventType: eventType, eventProperties: properties)
    }

    /// Tracks a SwiftUI screen view (screen-view autocapture only works for UIKit).
    static func trackScreen(_ screenName: String) {
        shared.track(eventType: "[Amplitude] Screen Viewed", eventProperties: [
            "screen_name": screenName
        ])
    }

    /// Sets a persistent user property via Amplitude's Identify API.
    ///
    /// User properties (not just events) are what Amplitude cohorts filter and
    /// segment on, so every cohort-relevant trait (subscription status, plan,
    /// language, lifetime counters, etc.) should be set through this method.
    static func setUserProperty(_ value: String, for key: String) {
        let identify = Identify()
        identify.set(property: key, value: value)
        shared.identify(identify: identify)
    }

    /// Sets a numeric user property (e.g. lifetime counters) via Identify.
    static func setUserProperty(_ value: Int, for key: String) {
        let identify = Identify()
        identify.set(property: key, value: value)
        shared.identify(identify: identify)
    }
}
