import Foundation

/// Forward-looking suppression window for any ad SDK (e.g. AdMob) integrated later.
/// No ad-serving code exists in the app yet, so this is currently a no-op signal store —
/// once ad presentation code lands, it must check `isAdSuppressed` before showing an ad.
enum AdGateService {
    private static let suppressedUntilKey = "adSuppressedUntilTimestamp"

    static func suppressAds(for duration: TimeInterval) {
        let until = Date().addingTimeInterval(duration)
        UserDefaults.standard.set(until.timeIntervalSince1970, forKey: suppressedUntilKey)
    }

    static var isAdSuppressed: Bool {
        let timestamp = UserDefaults.standard.double(forKey: suppressedUntilKey)
        guard timestamp > 0 else { return false }
        return Date().timeIntervalSince1970 < timestamp
    }
}
