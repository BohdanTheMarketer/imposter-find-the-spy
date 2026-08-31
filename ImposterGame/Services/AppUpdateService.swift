import Foundation
import UIKit

struct AppUpdateOffer: Equatable {
    let storeVersion: String
    let storeURL: URL
}

enum AppUpdateService {
    private static let bundleID = "com.danetka.Danetka"
    private static let lookupURL = URL(string: "https://itunes.apple.com/lookup?bundleId=com.danetka.Danetka")!
    private static let dismissedStoreVersionKey = "appUpdateDismissedStoreVersion"
    private static let lastCheckDayKey = "appUpdateLastCheckDay"

    #if DEBUG
    /// Shows a mock update prompt on every foreground. DEBUG builds only.
    static var isSimulationEnabled = false
    #endif

    @MainActor
    static func checkForUpdateIfNeeded() async -> AppUpdateOffer? {
        #if DEBUG
        if isSimulationEnabled {
            return simulationOffer()
        }
        #endif

        guard shouldCheckToday() else { return nil }
        recordCheckToday()

        guard let lookup = await fetchAppStoreLookup() else { return nil }
        guard isVersion(lookup.version, newerThan: currentAppVersion) else { return nil }
        guard !wasDismissed(storeVersion: lookup.version) else { return nil }

        return AppUpdateOffer(storeVersion: lookup.version, storeURL: lookup.url)
    }

    static func recordDismissal(storeVersion: String) {
        #if DEBUG
        if isSimulationEnabled { return }
        #endif
        UserDefaults.standard.set(storeVersion, forKey: dismissedStoreVersionKey)
    }

    @MainActor
    static func openAppStore(url: URL) {
        UIApplication.shared.open(url)
    }

    static func logPromptShown(localVersion: String, storeVersion: String) {
        AnalyticsService.logEvent("app_update_prompt_shown", parameters: [
            "local_version": localVersion,
            "store_version": storeVersion,
            "simulation": isSimulationContext
        ])
    }

    static func logUpdateTapped(localVersion: String, storeVersion: String) {
        AnalyticsService.logEvent("app_update_prompt_update_tapped", parameters: [
            "local_version": localVersion,
            "store_version": storeVersion,
            "simulation": isSimulationContext
        ])
    }

    static func logDismissed(localVersion: String, storeVersion: String) {
        AnalyticsService.logEvent("app_update_prompt_dismissed", parameters: [
            "local_version": localVersion,
            "store_version": storeVersion,
            "simulation": isSimulationContext
        ])
    }

    // MARK: - Private

    private static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private static var isSimulationContext: Bool {
        #if DEBUG
        return isSimulationEnabled
        #else
        return false
        #endif
    }

    #if DEBUG
    private static func simulationOffer() -> AppUpdateOffer {
        let mockVersion = bumpedVersion(from: currentAppVersion)
        let url = URL(string: "https://apps.apple.com/search?term=imposter")!
        return AppUpdateOffer(storeVersion: mockVersion, storeURL: url)
    }

    private static func bumpedVersion(from version: String) -> String {
        var parts = version.split(separator: ".").compactMap { Int($0) }
        if parts.isEmpty { return "99.0.0" }
        parts[parts.count - 1] += 1
        return parts.map(String.init).joined(separator: ".")
    }

    static func resetForQA() {
        UserDefaults.standard.removeObject(forKey: dismissedStoreVersionKey)
        UserDefaults.standard.removeObject(forKey: lastCheckDayKey)
    }
    #endif

    private struct LookupResult {
        let version: String
        let url: URL
    }

    private struct LookupResponse: Decodable {
        let resultCount: Int
        let results: [LookupEntry]

        struct LookupEntry: Decodable {
            let version: String
            let trackViewUrl: String
        }
    }

    private static func fetchAppStoreLookup() async -> LookupResult? {
        do {
            let (data, response) = try await URLSession.shared.data(from: lookupURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard decoded.resultCount > 0,
                  let entry = decoded.results.first,
                  let url = URL(string: entry.trackViewUrl)
            else { return nil }
            return LookupResult(version: entry.version, url: url)
        } catch {
            return nil
        }
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        compareVersions(lhs, rhs) == .orderedDescending
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func wasDismissed(storeVersion: String) -> Bool {
        UserDefaults.standard.string(forKey: dismissedStoreVersionKey) == storeVersion
    }

    private static func shouldCheckToday() -> Bool {
        let today = dayStamp(for: Date())
        return UserDefaults.standard.string(forKey: lastCheckDayKey) != today
    }

    private static func recordCheckToday() {
        UserDefaults.standard.set(dayStamp(for: Date()), forKey: lastCheckDayKey)
    }

    private static func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
