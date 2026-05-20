import Foundation
import SwiftUI

struct SupportedLocale: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let nativeName: String
    let englishName: String
}

/// Persists `AppleLanguages` so the next cold start picks bundled `.lproj` resources.
final class LocalizationService: ObservableObject {
    static let shared = LocalizationService()

    static let supportedLocales: [SupportedLocale] = [
        SupportedLocale(code: "en", nativeName: "English", englishName: "English"),
        SupportedLocale(code: "uk", nativeName: "Українська", englishName: "Ukrainian")
    ]

    @Published private(set) var currentLocaleCode: String

    private init() {
        if let override = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = override.first {
            currentLocaleCode = first
        } else {
            currentLocaleCode = Bundle.main.preferredLocalizations.first ?? "en"
        }
    }

    func selectLocale(code: String) {
        currentLocaleCode = code
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        objectWillChange.send()
    }

    func triggerRelaunch() {
        exit(0)
    }
}
