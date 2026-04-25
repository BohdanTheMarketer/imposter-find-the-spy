import Foundation
import Security
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    enum SubscriptionPlan {
        case weekly
        case yearly

        var analyticsValue: String {
            switch self {
            case .weekly: return "weekly"
            case .yearly: return "yearly"
            }
        }

        var productID: String {
            switch self {
            case .weekly:
                return "com.vertebro.imposter.weekly"
            case .yearly:
                return "com.vertebro.imposter.yearly"
            }
        }
    }

    enum AnalyticsSource: String {
        case inApp = "in_app"
        case restore = "restore"
    }

    private let isPremiumKey = "com.imposter.isPremium"
    private let premiumProductIDs = [
        "com.vertebro.imposter.weekly",
        "com.vertebro.imposter.yearly"
    ]
    private var transactionUpdatesTask: Task<Void, Never>?
    private var lastEntitlementState: AnalyticsService.SubscriptionEntitlementState?

    @Published var isPremium: Bool {
        didSet { keychainWrite(key: isPremiumKey, value: isPremium) }
    }
    @Published var productsByID: [String: Product] = [:]
    @Published var isStoreLoading = false

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false

    init() {
        self.isPremium = Self.keychainReadStatic(key: "com.imposter.isPremium")
        self.lastEntitlementState = self.isPremium ? .activeYearly : .inactive
        transactionUpdatesTask = observeTransactionUpdates()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus(trigger: "init")
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

    func purchaseSubscription(
        plan: SubscriptionPlan = .yearly,
        context: AnalyticsService.PaywallContext? = nil
    ) async -> Bool {
        await purchase(plan: plan, context: context)
    }

    func restorePurchases(context: AnalyticsService.PaywallContext? = nil) {
        Task {
            await restore(context: context)
        }
    }

    func refreshSubscriptionStatus(trigger: String = "manual_refresh") async {
        await refreshEntitlements(trigger: trigger)
    }

    var yearlyPlanSubtitleText: String {
        guard let product = productsByID[SubscriptionPlan.yearly.productID] else {
            return isStoreLoading ? "Loading price..." : "Just --/year"
        }
        return "Just \(product.displayPrice)/year"
    }

    var yearlyPlanWeeklyEquivalentText: String {
        guard let product = productsByID[SubscriptionPlan.yearly.productID] else {
            return isStoreLoading ? "Loading price..." : "--/week"
        }

        let yearlyPrice = NSDecimalNumber(decimal: product.price)
        let weeklyEquivalent = yearlyPrice
            .dividing(by: NSDecimalNumber(value: 365))
            .multiplying(by: NSDecimalNumber(value: 7))
            .decimalValue

        let localizedValue = weeklyEquivalent.formatted(product.priceFormatStyle)
        return "\(localizedValue)/week"
    }

    var weeklyPlanWeeklyPriceText: String {
        guard let product = productsByID[SubscriptionPlan.weekly.productID] else {
            return isStoreLoading ? "Loading price..." : "--/week"
        }
        return "\(product.displayPrice)/week"
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

    private func purchase(plan: SubscriptionPlan, context: AnalyticsService.PaywallContext?) async -> Bool {
        AnalyticsService.logSubscriptionAttempt(source: AnalyticsSource.inApp.rawValue)
        AnalyticsService.logPurchaseStarted(
            source: AnalyticsSource.inApp.rawValue,
            context: context,
            plan: plan.analyticsValue,
            productID: plan.productID
        )
        do {
            if productsByID[plan.productID] == nil {
                await loadProducts()
            }
            guard let product = productsByID[plan.productID] else {
                print("SubscriptionManager: product not found for \(plan.productID)")
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "product_not_found"
                )
                return false
            }

            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    print("SubscriptionManager: unverified transaction")
                    AnalyticsService.logPurchaseResult(
                        source: AnalyticsSource.inApp.rawValue,
                        context: context,
                        plan: plan.analyticsValue,
                        productID: plan.productID,
                        result: "success_unverified"
                    )
                    return false
                }
                await transaction.finish()
                await refreshSubscriptionStatus(trigger: "purchase_success")
                if isPremium {
                    hasCompletedOnboarding = true
                }
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: isPremium ? "success_verified" : "success_no_entitlement"
                )
                return isPremium
            case .userCancelled:
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "user_cancelled"
                )
                return false
            case .pending:
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "pending"
                )
                return false
            @unknown default:
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "unknown"
                )
                return false
            }
        } catch {
            print("SubscriptionManager: purchase failed - \(error)")
            AnalyticsService.logPurchaseResult(
                source: AnalyticsSource.inApp.rawValue,
                context: context,
                plan: plan.analyticsValue,
                productID: plan.productID,
                result: "error",
                errorCode: String(describing: error)
            )
            return false
        }
    }

    private func restore(context: AnalyticsService.PaywallContext?) async {
        AnalyticsService.logSubscriptionAttempt(source: AnalyticsSource.restore.rawValue)
        AnalyticsService.logRestoreStarted(source: AnalyticsSource.restore.rawValue, context: context)
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus(trigger: "restore_success")
            AnalyticsService.logRestoreResult(source: AnalyticsSource.restore.rawValue, context: context, result: "success")
        } catch {
            print("SubscriptionManager: restore failed - \(error)")
            AnalyticsService.logRestoreResult(
                source: AnalyticsSource.restore.rawValue,
                context: context,
                result: "error",
                errorCode: String(describing: error)
            )
        }
    }

    private func refreshEntitlements(trigger: String) async {
        var hasActiveSubscription = false
        var activeProductID: String?
        var activePlan: String?
        var hasRevokedSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard premiumProductIDs.contains(transaction.productID) else { continue }

            if transaction.revocationDate != nil {
                hasRevokedSubscription = true
                continue
            }

            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }

            hasActiveSubscription = true
            activeProductID = transaction.productID
            activePlan = transaction.productID == SubscriptionPlan.weekly.productID ? "weekly" : "yearly"
            break
        }

        let newState: AnalyticsService.SubscriptionEntitlementState
        if hasActiveSubscription {
            newState = activePlan == "weekly" ? .activeWeekly : .activeYearly
        } else if hasRevokedSubscription {
            newState = .revoked
        } else {
            newState = .inactive
        }

        if lastEntitlementState != newState {
            AnalyticsService.logEntitlementStateChanged(
                from: lastEntitlementState,
                to: newState,
                plan: activePlan,
                productID: activeProductID,
                trigger: trigger
            )
            lastEntitlementState = newState
        }

        isPremium = hasActiveSubscription
        syncSubscriptionUserProperties(plan: activePlan)
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshSubscriptionStatus(trigger: "transaction_update")
            }
        }
    }

    private func syncSubscriptionUserProperties(plan: String?) {
        AnalyticsService.setUserProperty(isPremium ? "true" : "false", for: "is_premium")
        AnalyticsService.setUserProperty(plan ?? "none", for: "active_plan")
        AnalyticsService.setUserProperty(hasCompletedOnboarding ? "true" : "false", for: "onboarding_completed")
    }
}
