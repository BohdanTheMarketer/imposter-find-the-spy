import Foundation
import Security
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    enum SubscriptionPlan {
        case weekly
        case yearly

        var productID: String {
            switch self {
            case .weekly:
                return "com.vertebro.imposter.weekly"
            case .yearly:
                return "com.vertebro.imposter.yearly"
            }
        }
    }

    private let isPremiumKey = "com.imposter.isPremium"
    private let premiumProductIDs = [
        "com.vertebro.imposter.weekly",
        "com.vertebro.imposter.yearly"
    ]
    private var transactionUpdatesTask: Task<Void, Never>?

    @Published var isPremium: Bool {
        didSet { keychainWrite(key: isPremiumKey, value: isPremium) }
    }
    @Published var productsByID: [String: Product] = [:]
    @Published var isStoreLoading = false

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false

    init() {
        self.isPremium = Self.keychainReadStatic(key: "com.imposter.isPremium")
        transactionUpdatesTask = observeTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
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

    func purchaseSubscription(plan: SubscriptionPlan = .yearly) async -> Bool {
        await purchase(plan: plan)
    }

    func restorePurchases() {
        Task {
            await restore()
        }
    }

    private func loadProducts() async {
        isStoreLoading = true
        defer { isStoreLoading = false }
        do {
            let products = try await Product.products(for: premiumProductIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            print("SubscriptionManager: failed loading products - \(error)")
        }
    }

    private func purchase(plan: SubscriptionPlan) async -> Bool {
        AnalyticsService.logSubscriptionAttempt(source: "in_app")
        do {
            if productsByID[plan.productID] == nil {
                await loadProducts()
            }
            guard let product = productsByID[plan.productID] else {
                print("SubscriptionManager: product not found for \(plan.productID)")
                return false
            }

            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    print("SubscriptionManager: unverified transaction")
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                if isPremium {
                    hasCompletedOnboarding = true
                }
                return isPremium
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("SubscriptionManager: purchase failed - \(error)")
            return false
        }
    }

    private func restore() async {
        AnalyticsService.logSubscriptionAttempt(source: "restore")
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            print("SubscriptionManager: restore failed - \(error)")
        }
    }

    private func refreshEntitlements() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard premiumProductIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }

            hasActiveSubscription = true
            break
        }

        isPremium = hasActiveSubscription
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }
}
