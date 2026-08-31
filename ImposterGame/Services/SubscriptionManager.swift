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
    private let purchaseAttributionKey = "com.imposter.analytics.purchaseAttribution"
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
    @Published var isPurchasing = false
    @Published var isRestoring = false
    /// In-memory (not persisted) - resets every app launch, unlike the AppStorage flags below.
    /// Set when the category paywall is actually shown; lets the post-game paywall skip itself
    /// for anyone who already saw+declined a paywall earlier in the SAME sitting, instead of
    /// stacking a third pitch on someone who just said no to the better-converting category paywall.
    @Published var hasSeenCategoryPaywallThisSession = false

    enum RestoreOutcome {
        case restored
        case noPurchasesFound
        case failed
    }

    enum PurchaseOutcome {
        case success
        case userCancelled
        case pending
        case failed
    }

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false
    @AppStorage("hasDeclinedOnboardingPaywall") var hasDeclinedOnboardingPaywall: Bool = false
    @AppStorage("hasShownPostGamePaywall") var hasShownPostGamePaywall: Bool = false

    /// Post-game soft paywall targets only users who saw and declined the onboarding paywall,
    /// haven't purchased, have never been shown this specific paywall before, and haven't ALSO
    /// seen the category paywall in this same sitting - avoids stacking a third pitch on someone
    /// who just declined the category paywall (which converts better than onboarding in practice).
    var isEligibleForPostGamePaywall: Bool {
        hasDeclinedOnboardingPaywall && !isPremium && !hasShownPostGamePaywall && !hasSeenCategoryPaywallThisSession
    }

    @discardableResult
    func markPostGamePaywallShown() -> Bool {
        guard isEligibleForPostGamePaywall else { return false }
        hasShownPostGamePaywall = true
        return true
    }

    init() {
        self.isPremium = Self.keychainReadStatic(key: "com.imposter.isPremium")
        // lastEntitlementState intentionally left nil - guessing a specific plan here (it used to
        // hardcode .activeYearly) meant weekly subscribers got a spurious "yearly -> weekly"
        // entitlement_state_changed logged on every single cold launch. Leaving it unresolved lets
        // the first real refreshEntitlements() call establish the true baseline silently; only
        // genuine transitions after that get logged.
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

    // MARK: - Keychain-backed analytics counters
    //
    // Payment-sequence/dedup/attribution bookkeeping used to live in UserDefaults, which is wiped
    // on reinstall - a real renewal (e.g. payment #5) would then log as payment_number=1 after a
    // reinstall, silently corrupting cohort/LTV depth analysis. Keychain survives reinstall (same
    // device), matching how `isPremium` itself is already persisted.

    private static func keychainReadData(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private func keychainWriteData(key: String, data: Data) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func keychainReadCodable<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = Self.keychainReadData(key: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func keychainWriteCodable<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        keychainWriteData(key: key, data: data)
    }

    func purchaseSubscription(
        plan: SubscriptionPlan = .yearly,
        context: AnalyticsService.PaywallContext? = nil
    ) async -> PurchaseOutcome {
        await purchase(plan: plan, context: context)
    }

    @discardableResult
    func restorePurchases(context: AnalyticsService.PaywallContext? = nil) async -> RestoreOutcome {
        await restore(context: context)
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

    /// Whether a real price is available for this plan yet - `false` while the placeholder
    /// ("Loading price...", "--/year") is what's actually on screen.
    func isPriceLoaded(for plan: SubscriptionPlan) -> Bool {
        productsByID[plan.productID] != nil
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

    /// Marketing "price broken into days" text (e.g. "$1.43/day"), shown on repeat paywall views.
    /// Actual billing terms remain weekly/yearly — see `billedPriceText`/`displayTerms`.
    func dailyPriceText(for plan: SubscriptionPlan) -> String {
        guard let product = productsByID[plan.productID] else {
            return isStoreLoading ? LocalizationService.shared.localized("paywall.price_loading") : "--/day"
        }
        let daysInPeriod: Decimal
        switch plan {
        case .weekly: daysInPeriod = 7
        case .yearly: daysInPeriod = 365
        }
        let dailyPrice = product.price / daysInPeriod
        let formatted = product.priceFormatStyle.format(dailyPrice)
        return LocalizationService.shared.localizedFormat("paywall.price_per_day_format", formatted)
    }

    var weeklyPlanDailyPriceText: String { dailyPriceText(for: .weekly) }
    var yearlyPlanDailyPriceText: String { dailyPriceText(for: .yearly) }

    /// Call when a paywall screen actually appears (and isn't auto-closing for an existing subscriber).
    /// Returns `true` if this is the very first time any paywall has been shown to this user.
    @discardableResult
    func markPaywallShown() -> Bool {
        let isFirstShow = !hasSeenPaywall
        hasSeenPaywall = true
        return isFirstShow
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
                // Failed to load products at all (e.g. no network) - don't stomp an eligibility
                // answer we already resolved on an earlier paywall appearance with this failure.
                downgradeToUnknownIfUnresolved()
            }
        }
    }

    private func purchase(plan: SubscriptionPlan, context: AnalyticsService.PaywallContext?) async -> PurchaseOutcome {
        guard !isPurchasing else { return .failed }
        isPurchasing = true
        defer { isPurchasing = false }

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
                return .failed
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
                    return .failed
                }
                // Persist attribution keyed by the transaction's stable originalID, not just the
                // in-memory "last purchase" - a later renewal for THIS transaction arrives via the
                // separate Transaction.updates listener, potentially long after the user has attempted
                // (or merely opened) a different paywall, which would otherwise overwrite/mis-tag it.
                persistPurchaseAttribution(originalID: transaction.originalID, context: context, trialEnabled: trialEnabled)
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
                return isPremium ? .success : .failed
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
                return .userCancelled
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
                return .pending
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
                return .failed
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
            return .failed
        }
    }

    private func restore(context: AnalyticsService.PaywallContext?) async -> RestoreOutcome {
        guard !isRestoring else { return .noPurchasesFound }
        isRestoring = true
        defer { isRestoring = false }

        AnalyticsService.logSubscriptionAttempt(source: AnalyticsSource.restore.rawValue)
        AnalyticsService.logRestoreStarted(source: AnalyticsSource.restore.rawValue, context: context)
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus(trigger: "restore_success")
            let outcome: RestoreOutcome = isPremium ? .restored : .noPurchasesFound
            AnalyticsService.logRestoreResult(
                source: AnalyticsSource.restore.rawValue,
                context: context,
                result: isPremium ? "success" : "no_purchases_found"
            )
            return outcome
        } catch {
            print("SubscriptionManager: restore failed - \(error)")
            AnalyticsService.logRestoreResult(
                source: AnalyticsSource.restore.rawValue,
                context: context,
                result: "error",
                errorCode: String(describing: error)
            )
            return .failed
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

        // Only log a "changed" event once we already had a confirmed prior state - the very first
        // resolution in this app lifetime just establishes the baseline silently, since `nil` here
        // means "not yet known", not "was inactive".
        if let previousState = lastEntitlementState, previousState != newState {
            AnalyticsService.logEntitlementStateChanged(
                from: previousState,
                to: newState,
                plan: activePlan,
                productID: activeProductID,
                trigger: trigger
            )
        }
        lastEntitlementState = newState

        isPremium = hasActiveSubscription
        syncSubscriptionUserProperties(plan: activePlan, isOnTrial: isOnTrial, hasRevokedSubscription: hasRevokedSubscription)
        await refreshTrialEligibilityState(trigger: "entitlements_\(trigger)")
    }

    private func refreshTrialEligibilityState(trigger: String) async {
        if isPremium {
            trialEligibilityState = .activeSubscriber
            return
        }

        // Product catalog not loaded yet (or failed to load) - eligibility is genuinely unknown here,
        // not "not eligible". Every paywall appearance re-runs this check from scratch, so a transient
        // miss on a LATER screen must not erase an already-resolved answer from an earlier one -
        // only downgrade to "unknown" if we don't already have a real answer.
        guard let weeklyProduct = productsByID[SubscriptionPlan.weekly.productID] else {
            downgradeToUnknownIfUnresolved()
            return
        }

        // Product loaded successfully and there's genuinely no introductory offer configured for it -
        // this is a real, confirmed answer, not a transient failure.
        guard let subscription = weeklyProduct.subscription, subscription.introductoryOffer != nil else {
            trialEligibilityState = .trialUsedOrExpired
            return
        }

        do {
            let eligible = try await Product.SubscriptionInfo.isEligibleForIntroOffer(for: subscription.subscriptionGroupID)
            trialEligibilityState = eligible ? .new : .trialUsedOrExpired
        } catch {
            print("SubscriptionManager: trial eligibility check failed [\(trigger)] - \(error)")
            // Network/StoreKit hiccup, not a confirmed "trial used" answer - don't stomp a
            // previously-resolved good answer (e.g. from an earlier paywall) with this failure.
            downgradeToUnknownIfUnresolved()
        }
    }

    /// Only moves eligibility to `.unknown` when we don't already have a confirmed answer -
    /// prevents a later, flaky re-check (every paywall appearance triggers one) from silently
    /// erasing a trial offer that was already successfully resolved earlier in the session.
    private func downgradeToUnknownIfUnresolved() {
        guard trialEligibilityState != .new, trialEligibilityState != .trialUsedOrExpired else { return }
        trialEligibilityState = .unknown
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                let attribution = await self?.purchaseAttribution(for: transaction.originalID)
                await self?.logSubscriptionTransactionIfNeeded(
                    transaction,
                    trigger: "transaction_update",
                    paywallContext: attribution?.context,
                    trialEnabled: attribution?.trialEnabled
                )
                await transaction.finish()
                await self?.refreshSubscriptionStatus(trigger: "transaction_update")
            }
        }
    }

    private struct PurchaseAttributionEntry: Codable {
        var context: String?
        var trialEnabled: Bool
    }

    /// Persists which paywall (and trial state) originated a transaction, keyed by its stable
    /// `originalID` - looked up later by `observeTransactionUpdates` for renewals/refunds that
    /// arrive out-of-band, long after the in-memory "last purchase" context has moved on.
    private func persistPurchaseAttribution(
        originalID: UInt64,
        context: AnalyticsService.PaywallContext?,
        trialEnabled: Bool
    ) {
        var attribution = keychainReadCodable([String: PurchaseAttributionEntry].self, key: purchaseAttributionKey) ?? [:]
        attribution[String(originalID)] = PurchaseAttributionEntry(context: context?.rawValue, trialEnabled: trialEnabled)
        if attribution.count > 500 {
            attribution = Dictionary(uniqueKeysWithValues: attribution.suffix(500))
        }
        keychainWriteCodable(attribution, key: purchaseAttributionKey)
    }

    private func purchaseAttribution(
        for originalID: UInt64
    ) -> (context: AnalyticsService.PaywallContext?, trialEnabled: Bool?) {
        let attribution = keychainReadCodable([String: PurchaseAttributionEntry].self, key: purchaseAttributionKey) ?? [:]
        guard let entry = attribution[String(originalID)] else { return (nil, nil) }
        let context = entry.context.flatMap(AnalyticsService.PaywallContext.init(rawValue:))
        return (context, entry.trialEnabled)
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
        let (value, currency) = priceInfo(for: transaction, transactionType: transactionType)

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

        // Funnel-friendly convenience events - lets analysts build a trial funnel directly by
        // event name instead of reconstructing it from subscription_transaction's
        // transaction_type/payment_number, which requires reading source code to decode.
        if transactionType == .trialStart {
            AnalyticsService.logTrialStarted(context: paywallContext, plan: plan)
        } else if transactionType == .renewal, paymentNumber == 1, trialEnabled == true {
            AnalyticsService.logTrialConverted(context: paywallContext, plan: plan)
        }
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
        let counters = keychainReadCodable([String: Int].self, key: paymentCountersKey) ?? [:]
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
        var counters = keychainReadCodable([String: Int].self, key: paymentCountersKey) ?? [:]
        let nextNumber = (counters[counterKey] ?? 0) + 1
        counters[counterKey] = nextNumber
        keychainWriteCodable(counters, key: paymentCountersKey)
        return nextNumber
    }

    private func priceInfo(
        for transaction: StoreKit.Transaction,
        transactionType: AnalyticsService.SubscriptionTransactionType
    ) -> (Double, String) {
        let currency = transactionCurrencyCode(for: transaction)
        if transactionType == .trialStart {
            return (0, currency)
        }
        guard let product = productsByID[transaction.productID] else {
            return (0, currency)
        }
        let amount = NSDecimalNumber(decimal: product.price).doubleValue
        // Refunds should net revenue DOWN in rollups, not just vanish from them.
        return (transactionType == .refund ? -amount : amount, currency)
    }

    /// The currency actually charged for this transaction — not the device's locale, which can
    /// differ from the App Store storefront and would otherwise mislabel real transactions.
    private func transactionCurrencyCode(for transaction: StoreKit.Transaction) -> String {
        if #available(iOS 17.0, *), let currency = transaction.currency {
            return currency.identifier
        }
        if let product = productsByID[transaction.productID] {
            return product.priceFormatStyle.currencyCode
        }
        return Locale.current.currency?.identifier ?? "USD"
    }

    private func hasLoggedTransaction(_ transactionID: UInt64) -> Bool {
        let loggedIDs = keychainReadCodable([String].self, key: loggedTransactionIDsKey) ?? []
        return loggedIDs.contains(String(transactionID))
    }

    private func markTransactionLogged(_ transactionID: UInt64) {
        var loggedIDs = keychainReadCodable([String].self, key: loggedTransactionIDsKey) ?? []
        loggedIDs.append(String(transactionID))
        if loggedIDs.count > 200 {
            loggedIDs = Array(loggedIDs.suffix(200))
        }
        keychainWriteCodable(loggedIDs, key: loggedTransactionIDsKey)
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
