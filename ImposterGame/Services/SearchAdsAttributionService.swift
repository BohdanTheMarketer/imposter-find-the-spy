import AdServices
import Foundation

/// Fetches Apple Search Ads attribution (campaign/ad group/keyword IDs) once per
/// install via Apple's native AdServices framework and mirrors it to Amplitude as
/// user properties. Free, on-device, no MMP/third-party SDK involved.
///
/// Organic installs (not driven by an Apple Search Ads tap) come back with
/// `attribution: false` and no campaign/keyword IDs - that's expected, not an error.
///
/// Apple's endpoint often answers 404 for the first minutes after install, and any network
/// blip used to lose the install's keyword for good. Now a launch retries a few times, and a
/// launch that still fails leaves it for the next one (up to `maxLaunchAttempts`).
enum SearchAdsAttributionService {
    private static let hasFetchedAttributionKey = "hasFetchedSearchAdsAttribution"
    private static let launchAttemptsKey = "searchAdsAttributionLaunchAttempts"
    /// Raw JSON from Apple, kept for the warehouse uploader (`raw.app_attribution`).
    static let payloadKey = "searchAdsAttributionPayload"

    private static let attributionEndpoint = URL(string: "https://api-adservices.apple.com/api/v1/")!
    private static let attemptsPerLaunch = 3
    private static let retryDelay: Duration = .seconds(5)
    private static let maxLaunchAttempts = 5

    static func fetchAttributionIfNeeded() {
        guard #available(iOS 14.3, *) else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hasFetchedAttributionKey) else { return }

        let launchAttempts = defaults.integer(forKey: launchAttemptsKey)
        guard launchAttempts < maxLaunchAttempts else { return }
        defaults.set(launchAttempts + 1, forKey: launchAttemptsKey)

        Task.detached(priority: .utility) {
            // A fresh token each try: it's cheap, and valid for 24h either way.
            for attempt in 1...attemptsPerLaunch {
                switch await requestAttribution() {
                case .resolved(let json, let data):
                    defaults.set(data, forKey: payloadKey)
                    defaults.set(true, forKey: hasFetchedAttributionKey)
                    applyAttribution(json)
                    WarehouseUploader.sendAttribution(data)
                    return
                case .permanentFailure:
                    // 400 = Apple rejected the token; retrying the same device won't change that.
                    defaults.set(true, forKey: hasFetchedAttributionKey)
                    return
                case .retryable:
                    if attempt < attemptsPerLaunch { try? await Task.sleep(for: retryDelay) }
                }
            }
        }
    }

    private enum Outcome {
        case resolved([String: Any], Data)
        case retryable
        case permanentFailure
    }

    @available(iOS 14.3, *)
    private static func requestAttribution() async -> Outcome {
        guard let token = try? AAAttribution.attributionToken() else { return .retryable }

        var request = URLRequest(url: attributionEndpoint)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = token.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .retryable }

        switch status {
        case 200:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .retryable
            }
            return .resolved(json, data)
        case 400:
            return .permanentFailure
        default:
            return .retryable   // 404 (not ready yet), 5xx
        }
    }

    private static func applyAttribution(_ json: [String: Any]) {
        for (key, value) in json {
            AmplitudeManager.setUserProperty(String(describing: value), for: "search_ads_\(key)")
        }
    }
}
