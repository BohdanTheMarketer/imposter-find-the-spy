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

    static func fetchAttributionIfNeeded() {
        guard #available(iOS 14.3, *) else { return }
        guard !UserDefaults.standard.bool(forKey: hasFetchedAttributionKey) else { return }
        // Mark attempted immediately - this is a once-ever fetch, not something to retry
        // on every launch (a transient network failure just means we miss this signal).
        UserDefaults.standard.set(true, forKey: hasFetchedAttributionKey)

        guard let token = try? AAAttribution.attributionToken() else { return }

        var request = URLRequest(url: attributionEndpoint)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = token.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            applyAttribution(json)
        }.resume()
    }

    private static func applyAttribution(_ json: [String: Any]) {
        for (key, value) in json {
            AmplitudeManager.setUserProperty(String(describing: value), for: "search_ads_\(key)")
        }
    }
}
