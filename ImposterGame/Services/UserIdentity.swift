import Foundation
import Security

/// The one user id shared by every analytics/payments system: BigQuery, Firebase/GA4, Amplitude,
/// and Apple itself (passed to Adapty as `appAccountToken`, which Apple then echoes back in every
/// App Store Server Notification for purchases made with it).
///
/// Kept in the Keychain so a reinstall on the same device keeps the same id - a reinstall that
/// minted a new id would split one paying user into two rows in the warehouse.
enum UserIdentity {
    private static let keychainAccount = "analytics_user_id"

    /// UUID form, as Adapty/StoreKit need it for `appAccountToken`.
    static let uuid: UUID = loadOrCreate()

    /// Lowercase string form - Apple returns `appAccountToken` lowercased in notifications,
    /// so every system gets the same spelling and joins don't depend on case.
    static var id: String { uuid.uuidString.lowercased() }

    private static func loadOrCreate() -> UUID {
        if let existing = read() { return existing }
        let fresh = UUID()
        write(fresh)
        return fresh
    }

    private static func read() -> UUID? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return UUID(uuidString: string)
    }

    private static func write(_ uuid: UUID) {
        let item: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainAccount,
            // Readable before first unlock: the id is needed during background launches too.
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData: Data(uuid.uuidString.utf8)
        ]
        SecItemAdd(item as CFDictionary, nil)
    }
}
