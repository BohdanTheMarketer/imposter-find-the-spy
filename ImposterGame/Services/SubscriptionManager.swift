import Foundation
import Security
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    enum TrialEligibilityState {
        case unknown
        case new
        case trialUsedOrExpired
        case activeSubscriber

        var analyticsValue: String {
            switch self {
            case .unknown: return "unknown"
            case .new: return "new"
            case .trialUsedOrExpired: return "trial_used"
            case .activeSubscriber: return "active_subscriber"
            }
        }
    }

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
    private let paymentCountersKey = "com.imposter.analytics.paymentCounters"
    private let loggedTransactionIDsKey = "com.imposter.analytics.loggedTransactionIDs"
    private let premiumProductIDs = [
        "com.vertebro.imposter.weekly",
        "com.vertebro.imposter.yearly"
    ]
    private var transactionUpdatesTask: Task<Void, Never>?
    private var lastEntitlementState: AnalyticsService.SubscriptionEntitlementState?
    private var lastPurchaseContext: AnalyticsService.PaywallContext?
    private var lastPurchaseTrialEnabled = false

    @Published var isPremium: Bool {
        didSet { keychainWrite(key: isPremiumKey, value: isPremium) }
    }
    @Published var productsByID: [String: Product] = [:]
    @Published var isStoreLoading = false
    @Published var trialEligibilityState: TrialEligibilityState = .unknown

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false

    init() {
        self.isPremium = Self.keychainReadStatic(key: "com.imposter.isPremium")
        self.lastEntitlementState = self.isPremium ? .activeYearly : .inactive
        transactionUpdatesTask = observeTransactionUpdates()
        Task {
            await loadProducts(trigger: "init")
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

    func refreshStoreProducts(trigger: String = "manual_refresh") async {
        await loadProducts(trigger: trigger)
    }

    var yearlyPlanBilledPriceText: String {
        guard let product = productsByID[SubscriptionPlan.yearly.productID] else {
            return isStoreLoading ? "Loading price..." : "--/year"
        }
        return "\(product.displayPrice)/year"
    }

    var weeklyPlanWeeklyPriceText: String {
        guard let product = productsByID[SubscriptionPlan.weekly.productID] else {
            return isStoreLoading ? "Loading price..." : "--/week"
        }
        return "\(product.displayPrice)/week"
    }

    func hasIntroOffer(for plan: SubscriptionPlan) -> Bool {
        guard let product = productsByID[plan.productID] else { return false }
        return product.subscription?.introductoryOffer != nil
    }

    var isEligibleForTrial: Bool {
        trialEligibilityState == .new
    }

    /// Billed recurring price for legal copy and CTA — always `/week` or `/year`, never intro-offer period units.
    func billedPriceText(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .weekly:
            return weeklyPlanWeeklyPriceText
        case .yearly:
            return yearlyPlanBilledPriceText
        }
    }

    func displayTerms(for plan: SubscriptionPlan) -> String {
        guard let product = productsByID[plan.productID] else {
            return LocalizationService.shared.localized("paywall.terms.fallback")
        }

        let billedPrice = billedPriceText(for: plan)
        if plan == .weekly,
           isEligibleForTrial,
           let introOffer = product.subscription?.introductoryOffer {
            let introDuration = subscriptionPeriodText(for: introOffer.period)
            return LocalizationService.shared.localizedFormat(
                "paywall.terms.trial_format",
                introDuration,
                billedPrice
            )
        }

        return LocalizationService.shared.localizedFormat(
            "paywall.terms.standard_format",
            billedPrice
        )
    }

    private func subscriptionPeriodText(for period: Product.SubscriptionPeriod) -> String {
        let unit = subscriptionUnitText(for: period.unit)
        if period.value == 1 {
            return "1 \(unit)"
        }
        return "\(period.value) \(unit)s"
    }

    private func subscriptionUnitText(for unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:
            return "day"
        case .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        @unknown default:
            return "period"
        }
    }

    private func loadProducts(trigger: String = "load_products") async {
        isStoreLoading = true
        defer { isStoreLoading = false }
        do {
            let products = try await Product.products(for: premiumProductIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            logLoadedProductPricing(trigger: trigger, products: products)
            await refreshTrialEligibilityState(trigger: "products_\(trigger)")
        } catch {
            print("SubscriptionManager: failed loading products - \(error)")
            if !isPremium {
                trialEligibilityState = .trialUsedOrExpired
            }
        }
    }

    private func purchase(plan: SubscriptionPlan, context: AnalyticsService.PaywallContext?) async -> Bool {
        let trialEnabled = plan == .weekly && isEligibleForTrial
        lastPurchaseContext = context
        lastPurchaseTrialEnabled = trialEnabled

        AnalyticsService.logSubscriptionAttempt(source: AnalyticsSource.inApp.rawValue)
        AnalyticsService.logPurchaseStarted(
            source: AnalyticsSource.inApp.rawValue,
            context: context,
            plan: plan.analyticsValue,
            productID: plan.productID,
            trialEnabled: trialEnabled,
            trialEligibility: trialEligibilityState.analyticsValue
        )
        do {
            if productsByID[plan.productID] == nil {
                await loadProducts(trigger: "purchase_missing_product")
            }
            guard let product = productsByID[plan.productID] else {
                print("SubscriptionManager: product not found for \(plan.productID)")
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "product_not_found",
                    trialEnabled: trialEnabled,
                    trialEligibility: trialEligibilityState.analyticsValue
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
                        result: "success_unverified",
                        trialEnabled: trialEnabled,
                        trialEligibility: trialEligibilityState.analyticsValue
                    )
                    return false
                }
                logSubscriptionTransactionIfNeeded(
                    transaction,
                    trigger: "purchase_success",
                    paywallContext: context,
                    trialEnabled: trialEnabled
                )
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
                    result: isPremium ? "success_verified" : "success_no_entitlement",
                    trialEnabled: trialEnabled,
                    trialEligibility: trialEligibilityState.analyticsValue
                )
                return isPremium
            case .userCancelled:
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "user_cancelled",
                    trialEnabled: trialEnabled,
                    trialEligibility: trialEligibilityState.analyticsValue
                )
                return false
            case .pending:
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "pending",
                    trialEnabled: trialEnabled,
                    trialEligibility: trialEligibilityState.analyticsValue
                )
                return false
            @unknown default:
                AnalyticsService.logPurchaseResult(
                    source: AnalyticsSource.inApp.rawValue,
                    context: context,
                    plan: plan.analyticsValue,
                    productID: plan.productID,
                    result: "unknown",
                    trialEnabled: trialEnabled,
                    trialEligibility: trialEligibilityState.analyticsValue
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
                trialEnabled: trialEnabled,
                trialEligibility: trialEligibilityState.analyticsValue,
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
        var isOnTrial = false

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
            isOnTrial = {
                if #available(iOS 17.0, *) {
                    return transaction.offerType == .introductory
                }
                return transaction.productID == SubscriptionPlan.weekly.productID
                    && trialEligibilityState == .activeSubscriber
            }()
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
        syncSubscriptionUserProperties(plan: activePlan, isOnTrial: isOnTrial, hasRevokedSubscription: hasRevokedSubscription)
        await refreshTrialEligibilityState(trigger: "entitlements_\(trigger)")
    }

    private func refreshTrialEligibilityState(trigger: String) async {
        if isPremium {
            trialEligibilityState = .activeSubscriber
            return
        }

        guard let weeklyProduct = productsByID[SubscriptionPlan.weekly.productID],
              let subscription = weeklyProduct.subscription,
              subscription.introductoryOffer != nil else {
            trialEligibilityState = .trialUsedOrExpired
            return
        }

        do {
            let eligible = try await Product.SubscriptionInfo.isEligibleForIntroOffer(for: subscription.subscriptionGroupID)
            trialEligibilityState = eligible ? .new : .trialUsedOrExpired
        } catch {
            print("SubscriptionManager: trial eligibility check failed [\(trigger)] - \(error)")
            trialEligibilityState = .trialUsedOrExpired
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                await self?.logSubscriptionTransactionIfNeeded(
                    transaction,
                    trigger: "transaction_update",
                    paywallContext: await self?.lastPurchaseContext,
                    trialEnabled: await self?.lastPurchaseTrialEnabled
                )
                await transaction.finish()
                await self?.refreshSubscriptionStatus(trigger: "transaction_update")
            }
        }
    }

    private func syncSubscriptionUserProperties(plan: String?, isOnTrial: Bool, hasRevokedSubscription: Bool) {
        AnalyticsService.setUserProperty(isPremium ? "true" : "false", for: "is_premium")
        AnalyticsService.setUserProperty(plan ?? "none", for: "active_plan")
        AnalyticsService.setUserProperty(hasCompletedOnboarding ? "true" : "false", for: "onboarding_completed")

        let status: AnalyticsService.SubscriptionStatus
        if isPremium {
            status = isOnTrial ? .trial : .paid
        } else if hasRevokedSubscription {
            status = .expired
        } else {
            status = .free
        }
        AnalyticsService.setSubscriptionStatus(status)
    }

    private func logSubscriptionTransactionIfNeeded(
        _ transaction: StoreKit.Transaction,
        trigger: String,
        paywallContext: AnalyticsService.PaywallContext?,
        trialEnabled: Bool?
    ) {
        guard premiumProductIDs.contains(transaction.productID) else { return }
        guard !hasLoggedTransaction(transaction.id) else { return }
        markTransactionLogged(transaction.id)

        let transactionType = subscriptionTransactionType(for: transaction)
        let offerType = offerTypeAnalytics(for: transaction)
        let plan = transaction.productID == SubscriptionPlan.weekly.productID ? "weekly" : "yearly"
        let paymentNumber = paymentNumber(for: transaction, transactionType: transactionType)
        let (value, currency) = priceInfo(for: transaction.productID, transactionType: transactionType)

        AnalyticsService.logSubscriptionTransaction(
            transactionType: transactionType,
            offerType: offerType,
            plan: plan,
            productID: transaction.productID,
            trigger: trigger,
            value: value,
            currency: currency,
            paymentNumber: paymentNumber,
            paywallContext: paywallContext,
            trialEnabled: trialEnabled
        )
    }

    private func subscriptionTransactionType(for transaction: StoreKit.Transaction) -> AnalyticsService.SubscriptionTransactionType {
        if transaction.revocationDate != nil {
            return .refund
        }
        if #available(iOS 17.0, *) {
            if transaction.reason == .renewal {
                return .renewal
            }
            if transaction.offerType == .introductory {
                return .trialStart
            }
            return .initialPurchase
        }

        let counterKey = String(transaction.originalID)
        let counters = UserDefaults.standard.dictionary(forKey: paymentCountersKey) as? [String: Int] ?? [:]
        if (counters[counterKey] ?? 0) > 0 {
            return .renewal
        }
        if transaction.productID == SubscriptionPlan.weekly.productID, lastPurchaseTrialEnabled {
            return .trialStart
        }
        return .initialPurchase
    }

    private func offerTypeAnalytics(for transaction: StoreKit.Transaction) -> AnalyticsService.OfferTypeAnalytics {
        if #available(iOS 17.0, *) {
            switch transaction.offerType {
            case .introductory:
                return .introductory
            case .promotional:
                return .promotional
            default:
                return .standard
            }
        }
        return subscriptionTransactionType(for: transaction) == .trialStart ? .introductory : .standard
    }

    private func paymentNumber(
        for transaction: StoreKit.Transaction,
        transactionType: AnalyticsService.SubscriptionTransactionType
    ) -> Int {
        if transactionType == .trialStart || transactionType == .refund {
            return 0
        }

        let counterKey = String(transaction.originalID)
        var counters = UserDefaults.standard.dictionary(forKey: paymentCountersKey) as? [String: Int] ?? [:]
        let nextNumber = (counters[counterKey] ?? 0) + 1
        counters[counterKey] = nextNumber
        UserDefaults.standard.set(counters, forKey: paymentCountersKey)
        return nextNumber
    }

    private func priceInfo(
        for productID: String,
        transactionType: AnalyticsService.SubscriptionTransactionType
    ) -> (Double, String) {
        if transactionType == .trialStart || transactionType == .refund {
            return (0, currencyCode)
        }
        guard let product = productsByID[productID] else {
            return (0, currencyCode)
        }
        return (NSDecimalNumber(decimal: product.price).doubleValue, currencyCode)
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private func hasLoggedTransaction(_ transactionID: UInt64) -> Bool {
        let loggedIDs = UserDefaults.standard.stringArray(forKey: loggedTransactionIDsKey) ?? []
        return loggedIDs.contains(String(transactionID))
    }

    private func markTransactionLogged(_ transactionID: UInt64) {
        var loggedIDs = UserDefaults.standard.stringArray(forKey: loggedTransactionIDsKey) ?? []
        loggedIDs.append(String(transactionID))
        if loggedIDs.count > 200 {
            loggedIDs = Array(loggedIDs.suffix(200))
        }
        UserDefaults.standard.set(loggedIDs, forKey: loggedTransactionIDsKey)
    }

    private func logLoadedProductPricing(trigger: String, products: [Product]) {
#if DEBUG
        for product in products {
            let value = NSDecimalNumber(decimal: product.price).stringValue
            print("SubscriptionManager: product loaded [\(trigger)] id=\(product.id) displayPrice=\(product.displayPrice) value=\(value)")
        }
#endif
    }
}
