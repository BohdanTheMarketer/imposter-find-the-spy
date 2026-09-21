import AdServices
import Foundation

/// Fetches Apple Search Ads attribution (campaign/ad group/keyword IDs) once per
/// install via Apple's native AdServices framework and mirrors it to Amplitude as
/// user properties. Free, on-device, no MMP/third-party SDK involved.
///
/// Organic installs (not driven by an Apple Search Ads tap) come back with
/// `attribution: false` and no campaign/keyword IDs - that's expected, not an error.
enum SearchAdsAttributionService {
    private static let hasFetchedAttributionKey = "hasFetchedSearchAdsAttribution"
    private static let attributionEndpoint = URL(string: "https://api-adservices.apple.com/api/v1/")!

    /// Apple only has the attribution ready a few seconds after first launch, so an early call
    /// can 404 - retry with backoff instead of losing the install's campaign for good.
    private static let retryDelays: [UInt64] = [5, 15, 60]

    static func fetchAttributionIfNeeded() {
        guard #available(iOS 14.3, *) else { return }
        guard !UserDefaults.standard.bool(forKey: hasFetchedAttributionKey) else { return }

        Task.detached(priority: .utility) {
            guard let token = try? AAAttribution.attributionToken() else { return }

            for attempt in 0...retryDelays.count {
                switch await requestAttribution(token: token) {
                case .resolved(let json):
                    // Done for good: only now is the once-ever flag set, so a network failure
                    // or a not-ready-yet 404 gets another chance on the next launch.
                    UserDefaults.standard.set(true, forKey: hasFetchedAttributionKey)
                    applyAttribution(json)
                    return
                case .retry:
                    guard attempt < retryDelays.count else { return }
                    try? await Task.sleep(nanoseconds: retryDelays[attempt] * 1_000_000_000)
                }
            }
        }
    }

    private enum Outcome {
        case resolved([String: Any])
        case retry
    }

    private static func requestAttribution(token: String) async -> Outcome {
        var request = URLRequest(url: attributionEndpoint)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = token.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .retry }
        guard status == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .retry
        }
        return .resolved(json)
    }

    /// Writes every field as a `search_ads_*` user property (so installs, trials and purchases -
    /// including Adapty's server-side revenue events - can all be grouped by campaign/keyword)
    /// and fires one event so the install itself is countable per campaign.
    private static func applyAttribution(_ json: [String: Any]) {
        var properties: [String: Any] = [:]
        for (key, value) in json {
            properties["search_ads_\(key)"] = String(describing: value)
        }
        AmplitudeManager.setUserProperties(properties)
        AmplitudeManager.track("search_ads_attribution_resolved", properties: properties)
    }
}
