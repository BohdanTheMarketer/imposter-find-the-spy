import Foundation
import SwiftUI

struct SupportedLocale: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let flag: String
    let nativeName: String
    let englishName: String
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}

/// Manages in-app language override with immediate UI updates (no restart).
final class LocalizationService: ObservableObject {
    static let shared = LocalizationService()

    static let supportedLocales: [SupportedLocale] = [
        SupportedLocale(code: "en", flag: "🇺🇸", nativeName: "English", englishName: "English"),
        SupportedLocale(code: "pt-BR", flag: "🇧🇷", nativeName: "Português", englishName: "Portuguese (Brazil)"),
        SupportedLocale(code: "fr", flag: "🇫🇷", nativeName: "Français", englishName: "French"),
        SupportedLocale(code: "es-MX", flag: "🇲🇽", nativeName: "Español", englishName: "Spanish (LATAM)"),
        SupportedLocale(code: "tr", flag: "🇹🇷", nativeName: "Türkçe", englishName: "Turkish")
    ]

    @Published private(set) var currentLocaleCode: String

    var locale: Locale {
        Locale(identifier: currentLocaleCode)
    }

    private init() {
        if let override = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = override.first {
            currentLocaleCode = first
        } else {
            currentLocaleCode = Bundle.main.preferredLocalizations.first ?? "en"
        }
        applyLanguage(currentLocaleCode, notify: false)
    }

    func selectLocale(code: String) {
        guard code != currentLocaleCode else { return }
        applyLanguage(code, notify: true)
    }

    var currentLocale: SupportedLocale? {
        Self.supportedLocales.first { $0.code == currentLocaleCode }
    }

    /// String from the active runtime language bundle (`Bundle.setAppLanguage`).
    func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    /// `Localizable.strings` format string (`%lld`, `%@`, …).
    func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: locale, arguments: arguments)
    }

    /// `Localizable.stringsdict` plural rule (e.g. `voting.select_count`).
    func localizedPluralFormat(_ key: String, _ count: Int) -> String {
        let format = String(
            localized: String.LocalizationValue(key),
            bundle: .main,
            locale: locale
        )
        return String(format: format, locale: locale, arguments: [count])
    }

    private func applyLanguage(_ code: String, notify: Bool) {
        currentLocaleCode = code
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        Bundle.setAppLanguage(code)

        if notify {
            NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
            objectWillChange.send()
        }
    }
}
