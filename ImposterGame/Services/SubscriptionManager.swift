import Foundation
import Security
import SwiftUI

class SubscriptionManager: ObservableObject {
    private let isPremiumKey = "com.imposter.isPremium"

    @Published var isPremium: Bool {
        didSet { keychainWrite(key: isPremiumKey, value: isPremium) }
    }

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false

    init() {
        self.isPremium = Self.keychainReadStatic(key: "com.imposter.isPremium")
    }

    private static func keychainReadStatic(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let byte = data.first else { return false }
        return byte != 0
    }

    private func keychainRead(key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let byte = data.first else { return false }
        return byte != 0
    }

    private func keychainWrite(key: String, value: Bool) {
        let data = Data([value ? 1 : 0])
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attributes: [CFString: Any] = [kSecValueData: data]
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    func purchaseSubscription() {
        #warning("RevenueCat integration required before App Store submission")
        // TODO: Integrate RevenueCat
        // For now, unlock premium for testing
        AnalyticsService.logSubscriptionAttempt(source: "in_app")
        isPremium = true
        hasCompletedOnboarding = true
    }

    func restorePurchases() {
        #warning("RevenueCat integration required before App Store submission")
        // TODO: Integrate RevenueCat restore
        AnalyticsService.logSubscriptionAttempt(source: "restore")
    }
}
