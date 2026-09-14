import Adapty
import Combine
import Foundation
import Security
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
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
    private var profileCancellable: AnyCancellable?
    private var lastEntitlementState: AnalyticsService.SubscriptionEntitlementState?

    @Published var isPremium: Bool {
        didSet { keychainWrite(key: isPremiumKey, value: isPremium) }
    }
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
        // React in real time whenever Adapty pushes a fresh profile - e.g. a server-side
        // entitlement change, or the Flow UI completing a purchase/restore internally and
        // updating AdaptyService.profile out-of-band from any explicit refresh call here.
        //
        // The emitted value is used directly (not re-read off AdaptyService) because `@Published`
        // publishes in `willSet`. `compactMap` drops the `nil` that the publisher replays
        // synchronously on subscribe, which would otherwise run a full sync - wiping the Keychain
        // cache and burning the entitlement-change baseline - before Adapty has even activated.
        profileCancellable = AdaptyService.shared.$profile
            .compactMap { $0 }
            .sink { [weak self] profile in
                self?.syncPremiumStatus(profile: profile, trigger: "adapty_profile_update")
            }
        Task {
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

    /// Call when a paywall screen actually appears (and isn't auto-closing for an existing subscriber).
    /// Returns `true` if this is the very first time any paywall has been shown to this user.
    @discardableResult
    func markPaywallShown() -> Bool {
        let isFirstShow = !hasSeenPaywall
        hasSeenPaywall = true
        return isFirstShow
    }

    func refreshSubscriptionStatus(trigger: String = "manual_refresh") async {
        await refreshEntitlements(trigger: trigger)
    }

    private func refreshEntitlements(trigger: String) async {
        await AdaptyService.shared.reloadProfile()
        syncPremiumStatus(profile: AdaptyService.shared.profile, trigger: trigger)
    }

    /// Maps a store product id to the plan name used throughout analytics. Falls back to "yearly"
    /// for any id that isn't the weekly product, mirroring the previous `SubscriptionPlan` mapping.
    private func planName(for productID: String) -> String {
        productID == premiumProductIDs[0] ? "weekly" : "yearly"
    }

    /// Recomputes `isPremium` (and the associated analytics side effects) from Adapty's profile -
    /// the single source of truth for entitlement now, instead of a StoreKit
    /// `Transaction.currentEntitlements` scan.
    ///
    /// The profile is passed in rather than read back off `AdaptyService`: `@Published` fires its
    /// publisher in `willSet`, so a subscriber that re-reads the property sees the PREVIOUS value
    /// and every server-pushed update would be processed one step stale.
    ///
    /// A `nil` profile means "not resolved yet" (SDK still activating, offline, request failed) -
    /// never "no subscription". Treating it as the latter downgrades a paying subscriber and, via
    /// `isPremium`'s `didSet`, poisons the Keychain cache that exists precisely to carry their
    /// access across launches with no network.
    private func syncPremiumStatus(profile: AdaptyProfile?, trigger: String) {
        guard let profile else { return }

        let accessLevel = profile.accessLevels[AppConstants.adaptyAccessLevelId]
        let hasActiveSubscription = accessLevel?.isActive ?? false
        let activeProductID = hasActiveSubscription ? accessLevel?.vendorProductId : nil
        let activePlan = activeProductID.map(planName(for:))
        let isOnTrial = hasActiveSubscription && accessLevel?.activeIntroductoryOfferType != nil
        let hasRevokedSubscription = !hasActiveSubscription && (accessLevel?.isRefund ?? false)

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
    }

    // MARK: - Adapty Flow purchase/restore analytics wrappers
    //
    // The Adapty Flow's own CTA / restore link performs the actual purchase/restore call itself
    // (via Adapty.makePurchase()/Adapty.restorePurchases() internally) - these methods don't call
    // into StoreKit or Adapty themselves. They're invoked from each paywall view's Flow event
    // callbacks and just run the same analytics + state-flag side effects the old app-initiated
    // purchase/restore flow used to run inline around its own `product.purchase()` call.

    /// The user switched plan cards inside the Flow. Keeps the mid-funnel plan-mix visible, which
    /// the pre-migration paywalls logged from their own plan pickers.
    func handleFlowProductSelected(product: AdaptyPaywallProduct, context: AnalyticsService.PaywallContext) {
        AnalyticsService.logPaywallPlanSelected(
            context: context,
            plan: planName(for: product.vendorProductId),
            trialEnabled: isTrialOffer(product)
        )
    }

    /// A tap on one of the Flow's links (terms, privacy). The Flow reports a URL rather than a
    /// semantic type, so the type is recovered from the URL itself.
    func handleFlowLinkTapped(url: URL, context: AnalyticsService.PaywallContext) {
        let haystack = url.absoluteString.lowercased()
        let linkType: String
        if haystack.contains("privacy") {
            linkType = "privacy"
        } else if haystack.contains("terms") || haystack.contains("eula") {
            linkType = "terms"
        } else {
            linkType = "other"
        }
        AnalyticsService.logPaywallLinkTapped(context: context, linkType: linkType)
    }

    func handleFlowPurchaseStarted(product: AdaptyPaywallProduct, context: AnalyticsService.PaywallContext?) {
        isPurchasing = true
        let trialEnabled = isTrialOffer(product)
        let plan = planName(for: product.vendorProductId)
        if let context {
            AnalyticsService.logPaywallContinueTapped(context: context, plan: plan, trialEnabled: trialEnabled)
        }
        AnalyticsService.logSubscriptionAttempt(source: AnalyticsSource.inApp.rawValue)
        AnalyticsService.logPurchaseStarted(
            source: AnalyticsSource.inApp.rawValue,
            context: context,
            plan: plan,
            productID: product.vendorProductId,
            trialEnabled: trialEnabled,
            trialEligibility: trialEligibilityValue(for: product)
        )
    }

    /// Returns `true` only when the purchase actually resulted in active paid access. A `.success`
    /// whose profile does not yet carry the access level is NOT success as far as the UI is
    /// concerned - closing the paywall on it leaves a user who just paid looking at locked content.
    @discardableResult
    func handleFlowPurchaseFinished(
        product: AdaptyPaywallProduct,
        result: AdaptyPurchaseResult,
        context: AnalyticsService.PaywallContext?
    ) -> Bool {
        isPurchasing = false
        let plan = planName(for: product.vendorProductId)
        let trialEnabled = isTrialOffer(product)
        let trialEligibility = trialEligibilityValue(for: product)

        switch result {
        case .userCancelled:
            AnalyticsService.logPurchaseResult(
                source: AnalyticsSource.inApp.rawValue,
                context: context,
                plan: plan,
                productID: product.vendorProductId,
                result: "user_cancelled",
                trialEnabled: trialEnabled,
                trialEligibility: trialEligibility
            )
        case .pending:
            AnalyticsService.logPurchaseResult(
                source: AnalyticsSource.inApp.rawValue,
                context: context,
                plan: plan,
                productID: product.vendorProductId,
                result: "pending",
                trialEnabled: trialEnabled,
                trialEligibility: trialEligibility
            )
        case let .success(profile, transaction):
            // Sync first so the entitlement-change event carries the "purchase_success" trigger,
            // then publish the profile - the subscription then sees no further change and stays
            // quiet, instead of claiming the transition as a generic profile update.
            syncPremiumStatus(profile: profile, trigger: "purchase_success")
            AdaptyService.shared.profile = profile
            // Persist attribution + log the underlying StoreKit transaction the same way a
            // directly app-initiated purchase used to - keyed by originalID so a later renewal
            // arriving via `Transaction.updates` (observeTransactionUpdates below) can still find
            // it. `logSubscriptionTransactionIfNeeded` dedupes by transaction id, so if the
            // Transaction.updates listener also sees this same transaction it won't double-log.
            if case let .verified(skTransaction) = transaction {
                persistPurchaseAttribution(originalID: skTransaction.originalID, context: context, trialEnabled: trialEnabled)
                logSubscriptionTransactionIfNeeded(
                    skTransaction,
                    trigger: "purchase_success",
                    paywallContext: context,
                    trialEnabled: trialEnabled
                )
            }
            if isPremium {
                hasCompletedOnboarding = true
            }
            AnalyticsService.logPurchaseResult(
                source: AnalyticsSource.inApp.rawValue,
                context: context,
                plan: plan,
                productID: product.vendorProductId,
                result: isPremium ? "success_verified" : "success_no_entitlement",
                trialEnabled: trialEnabled,
                trialEligibility: trialEligibility
            )
            return isPremium
        @unknown default:
            AnalyticsService.logPurchaseResult(
                source: AnalyticsSource.inApp.rawValue,
                context: context,
                plan: plan,
                productID: product.vendorProductId,
                result: "unknown",
                trialEnabled: trialEnabled,
                trialEligibility: trialEligibility
            )
        }
        return false
    }

    func handleFlowPurchaseFailed(
        product: AdaptyPaywallProduct,
        error: AdaptyError,
        context: AnalyticsService.PaywallContext?
    ) {
        isPurchasing = false
        AnalyticsService.logPurchaseResult(
            source: AnalyticsSource.inApp.rawValue,
            context: context,
            plan: planName(for: product.vendorProductId),
            productID: product.vendorProductId,
            result: "error",
            trialEnabled: isTrialOffer(product),
            trialEligibility: trialEligibilityValue(for: product),
            errorCode: String(describing: error)
        )
    }

    func handleFlowRestoreStarted(context: AnalyticsService.PaywallContext?) {
        isRestoring = true
        if let context {
            AnalyticsService.logPaywallRestoreTapped(context: context)
        }
        AnalyticsService.logSubscriptionAttempt(source: AnalyticsSource.restore.rawValue)
        AnalyticsService.logRestoreStarted(source: AnalyticsSource.restore.rawValue, context: context)
    }

    @discardableResult
    func handleFlowRestoreFinished(profile: AdaptyProfile, context: AnalyticsService.PaywallContext?) -> RestoreOutcome {
        isRestoring = false
        syncPremiumStatus(profile: profile, trigger: "restore_success")
        AdaptyService.shared.profile = profile
        let outcome: RestoreOutcome = isPremium ? .restored : .noPurchasesFound
        AnalyticsService.logRestoreResult(
            source: AnalyticsSource.restore.rawValue,
            context: context,
            result: isPremium ? "success" : "no_purchases_found"
        )
        return outcome
    }

    func handleFlowRestoreFailed(error: AdaptyError, context: AnalyticsService.PaywallContext?) {
        isRestoring = false
        AnalyticsService.logRestoreResult(
            source: AnalyticsSource.restore.rawValue,
            context: context,
            result: "error",
            errorCode: String(describing: error)
        )
    }

    /// Whether the offer Adapty attached to this product is a free trial specifically.
    ///
    /// Mere presence of a `subscriptionOffer` is NOT a trial signal: the same field carries
    /// promotional and win-back offers, so a trial-exhausted user shown a win-back deal would
    /// otherwise report as a trial start. Only `.introductory` is the intro/trial offer whose
    /// eligibility Apple determines per subscription group.
    private func isTrialOffer(_ product: AdaptyPaywallProduct) -> Bool {
        product.subscriptionOffer?.offerType == .introductory
    }

    /// Approximates the old `trialEligibilityState` for analytics: Adapty attaches an introductory
    /// offer only when this device/account is actually eligible for it, so its presence on the
    /// weekly product stands in for "new" vs "trial used" without a separate StoreKit check.
    private func trialEligibilityValue(for product: AdaptyPaywallProduct) -> String {
        guard product.vendorProductId == premiumProductIDs[0] else { return "n/a" }
        return isTrialOffer(product) ? "new" : "trial_used"
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

    // MARK: - Raw StoreKit transaction analytics pipeline
    //
    // Kept alive purely for analytics (transaction type/payment number/price/currency/sandbox
    // filtering/attribution) - this reads StoreKit's own transaction stream directly, which does
    // not conflict with Adapty also processing the same stream. `isPremium` is no longer derived
    // from this; see `syncPremiumStatus` above.

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
                // Deliberately NOT calling transaction.finish() here. Adapty owns the purchase
                // now and finishes transactions itself, after reporting them to its backend.
                // Finishing first would let StoreKit stop redelivering a transaction Adapty has
                // not yet validated (e.g. the report failed offline), silently losing the renewal.
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

    private func logSubscriptionTransactionIfNeeded(
        _ transaction: StoreKit.Transaction,
        trigger: String,
        paywallContext: AnalyticsService.PaywallContext?,
        trialEnabled: Bool?
    ) {
        guard premiumProductIDs.contains(transaction.productID) else { return }
        // Sandbox transactions (TestFlight/dev builds, App Store sandbox testers) rebill in
        // minutes instead of days/weeks and carry no real money - they'd otherwise flood
        // Amplitude with fake renewal bursts and pollute revenue/geo analytics.
        guard transaction.environment != .sandbox else { return }
        guard !hasLoggedTransaction(transaction.id) else { return }
        markTransactionLogged(transaction.id)

        let transactionType = subscriptionTransactionType(for: transaction)
        let offerType = offerTypeAnalytics(for: transaction)
        let plan = planName(for: transaction.productID)
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
            purchaseDate: transaction.purchaseDate,
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
        if transaction.productID == premiumProductIDs[0] {
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
        guard let price = transaction.price else {
            return (0, currency)
        }
        let amount = NSDecimalNumber(decimal: price).doubleValue
        // Refunds should net revenue DOWN in rollups, not just vanish from them.
        return (transactionType == .refund ? -amount : amount, currency)
    }

    /// The currency actually charged for this transaction — not the device's locale, which can
    /// differ from the App Store storefront and would otherwise mislabel real transactions.
    private func transactionCurrencyCode(for transaction: StoreKit.Transaction) -> String {
        if #available(iOS 17.0, *), let currency = transaction.currency {
            return currency.identifier
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
}
