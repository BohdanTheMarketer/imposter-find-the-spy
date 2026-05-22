import Foundation

private var associatedLanguageBundleKey: UInt8 = 0

/// Routes `Bundle.main` string lookups to the active `.lproj` folder at runtime.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        if let bundle = objc_getAssociatedObject(self, &associatedLanguageBundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Switches which `.lproj` folder `Bundle.main` reads for localized strings.
    static func setAppLanguage(_ languageCode: String) {
        object_setClass(Bundle.main, LocalizedBundle.self)

        let bundle =
            bundleForLproj(named: languageCode)
            ?? bundleForLproj(named: String(languageCode.prefix(2)))
            ?? Bundle.main

        objc_setAssociatedObject(
            Bundle.main,
            &associatedLanguageBundleKey,
            bundle,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static func bundleForLproj(named code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
