import Foundation

private var associatedLanguageBundleKey: UInt8 = 0

/// Routes `Bundle.main` string lookups to the active `.lproj` folder at runtime.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    private static let lock = NSLock()

    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        guard let bundle = objc_getAssociatedObject(self, &associatedLanguageBundleKey) as? Bundle,
              bundle !== Bundle.main else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    private static let languageBundleLock = NSLock()

    /// Maps device / StoreKit locale codes to bundled `.lproj` folder names.
    private static let lprojAliases: [String: String] = [
        "es": "es-MX",
        "pt": "pt-BR"
    ]

    /// Switches which `.lproj` folder `Bundle.main` reads for localized strings.
    static func setAppLanguage(_ languageCode: String) {
        languageBundleLock.lock()
        defer { languageBundleLock.unlock() }

        object_setClass(Bundle.main, LocalizedBundle.self)

        let bundle = languageBundle(for: languageCode)
            ?? languageBundle(for: "en")
            ?? Bundle(path: Bundle.main.bundlePath)

        objc_setAssociatedObject(
            Bundle.main,
            &associatedLanguageBundleKey,
            bundle,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static func languageBundle(for code: String) -> Bundle? {
        if let bundle = bundleForLproj(named: code) {
            return bundle
        }
        if let alias = lprojAliases[code], let bundle = bundleForLproj(named: alias) {
            return bundle
        }
        let baseCode = code.split(separator: "-").first.map(String.init) ?? code
        if baseCode != code, let bundle = bundleForLproj(named: baseCode) {
            return bundle
        }
        if let alias = lprojAliases[baseCode], let bundle = bundleForLproj(named: alias) {
            return bundle
        }
        return nil
    }

    private static func bundleForLproj(named code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
