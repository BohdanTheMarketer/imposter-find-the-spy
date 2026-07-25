import FirebaseAnalytics
import Foundation

enum AnalyticsService {
    enum PaywallContext: String {
        case onboarding
        case category
    }

    enum PaywallCloseReason: String {
        case closeButton = "close_button"
        case skip = "skip"
        case purchaseSuccess = "purchase_success"
    }

    enum SubscriptionEntitlementState: String {
        case inactive
        case activeWeekly = "active_weekly"
        case activeYearly = "active_yearly"
        case revoked
    }

    enum SubscriptionTransactionType: String {
        case trialStart = "trial_start"
        case initialPurchase = "initial_purchase"
        case renewal = "renewal"
        case refund = "refund"
    }

    enum OfferTypeAnalytics: String {
        case introductory
        case standard
        case promotional
    }

    enum SubscriptionStatus: String {
        case free
        case trial
        case paid
        case expired
    }

    static func logScreenView(for screen: AppScreen) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screen.rawValue,
            AnalyticsParameterScreenClass: screen.rawValue
        ])
        // Mirror to Amplitude (SwiftUI screen views aren't autocaptured).
        AmplitudeManager.trackScreen(screen.rawValue)
    }

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
        // Mirror the same event to Amplitude.
        AmplitudeManager.track(name, properties: parameters)
    }

    static func logGameStart(category: String, playerCount: Int, imposterCount: Int) {
        logEvent("game_start", parameters: [
            "category": category,
            "player_count": playerCount,
            "imposter_count": imposterCount
        ])
    }

    static func logGameEnd(result: String, duration: Int) {
        logEvent("game_end", parameters: [
            "result": result,
            "round_duration": duration
        ])
    }

    static func logSubscriptionAttempt(source: String) {
        logEvent("subscription_attempt", parameters: ["source": source])
    }

    static func setUserProperty(_ value: String?, for key: String) {
        Analytics.setUserProperty(value, forName: key)
        // Mirror to Amplitude so cohorts can filter/segment on this property.
        if let value {
            AmplitudeManager.setUserProperty(value, for: key)
        }
    }

    static func logPaywallViewed(context: PaywallContext) {
        logEvent("paywall_viewed", parameters: [
            "paywall_context": context.rawValue
        ])
    }

    static func logPaywallClosed(context: PaywallContext, reason: PaywallCloseReason) {
        logEvent("paywall_closed", parameters: [
            "paywall_context": context.rawValue,
            "close_reason": reason.rawValue
        ])
    }

    static func logPaywallPlanSelected(context: PaywallContext, plan: String, trialEnabled: Bool) {
        logEvent("paywall_plan_selected", parameters: [
            "paywall_context": context.rawValue,
            "plan": plan,
            "trial_enabled": trialEnabled
        ])
    }

    static func logPaywallTrialToggled(context: PaywallContext, enabled: Bool) {
        logEvent("paywall_trial_toggled", parameters: [
            "paywall_context": context.rawValue,
            "trial_enabled": enabled
        ])
    }

    static func logPaywallContinueTapped(context: PaywallContext, plan: String, trialEnabled: Bool) {
        logEvent("paywall_continue_tapped", parameters: [
            "paywall_context": context.rawValue,
            "plan": plan,
            "trial_enabled": trialEnabled
        ])
    }

    static func logPaywallRestoreTapped(context: PaywallContext) {
        logEvent("paywall_restore_tapped", parameters: [
            "paywall_context": context.rawValue
        ])
    }

    static func logPaywallLinkTapped(context: PaywallContext, linkType: String) {
        logEvent("paywall_link_tapped", parameters: [
            "paywall_context": context.rawValue,
            "link_type": linkType
        ])
    }

    static func logPurchaseStarted(
        source: String,
        context: PaywallContext?,
        plan: String,
        productID: String,
        trialEnabled: Bool,
        trialEligibility: String
    ) {
        logEvent("purchase_started", parameters: [
            "source": source,
            "paywall_context": context?.rawValue ?? "unknown",
            "plan": plan,
            "product_id": productID,
            "trial_enabled": trialEnabled,
            "trial_eligibility": trialEligibility
        ])
    }

    static func logPurchaseResult(
        source: String,
        context: PaywallContext?,
        plan: String,
        productID: String,
        result: String,
        trialEnabled: Bool,
        trialEligibility: String,
        errorCode: String? = nil
    ) {
        var params: [String: Any] = [
            "source": source,
            "paywall_context": context?.rawValue ?? "unknown",
            "plan": plan,
            "product_id": productID,
            "result": result,
            "trial_enabled": trialEnabled,
            "trial_eligibility": trialEligibility
        ]
        if let errorCode {
            params["error_code"] = errorCode
        }
        logEvent("purchase_result", parameters: params)
    }

    static func logSubscriptionTransaction(
        transactionType: SubscriptionTransactionType,
        offerType: OfferTypeAnalytics,
        plan: String,
        productID: String,
        trigger: String,
        value: Double,
        currency: String,
        paymentNumber: Int,
        paywallContext: PaywallContext? = nil,
        trialEnabled: Bool? = nil
    ) {
        var params: [String: Any] = [
            "transaction_type": transactionType.rawValue,
            "offer_type": offerType.rawValue,
            "plan": plan,
            "product_id": productID,
            "trigger": trigger,
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency,
            "payment_number": paymentNumber
        ]
        if let paywallContext {
            params["paywall_context"] = paywallContext.rawValue
        }
        if let trialEnabled {
            params["trial_enabled"] = trialEnabled
        }
        logEvent("subscription_transaction", parameters: params)
    }

    static func setInstallWeekIfNeeded() {
        let key = "com.imposter.analytics.installWeekSet"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let calendar = Calendar(identifier: .iso8601)
        let week = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let installWeek = String(format: "%d-W%02d", year, week)
        setUserProperty(installWeek, for: "install_week")
        UserDefaults.standard.set(true, forKey: key)
    }

    static func setSubscriptionStatus(_ status: SubscriptionStatus) {
        setUserProperty(status.rawValue, for: "subscription_status")
    }

    static func logRestoreStarted(source: String, context: PaywallContext?) {
        logEvent("restore_started", parameters: [
            "source": source,
            "paywall_context": context?.rawValue ?? "unknown"
        ])
    }

    static func logRestoreResult(source: String, context: PaywallContext?, result: String, errorCode: String? = nil) {
        var params: [String: Any] = [
            "source": source,
            "paywall_context": context?.rawValue ?? "unknown",
            "result": result
        ]
        if let errorCode {
            params["error_code"] = errorCode
        }
        logEvent("restore_result", parameters: params)
    }

    static func logEntitlementStateChanged(
        from oldState: SubscriptionEntitlementState?,
        to newState: SubscriptionEntitlementState,
        plan: String?,
        productID: String?,
        trigger: String
    ) {
        var params: [String: Any] = [
            "to_state": newState.rawValue,
            "trigger": trigger
        ]
        if let oldState {
            params["from_state"] = oldState.rawValue
        }
        if let plan {
            params["plan"] = plan
        }
        if let productID {
            params["product_id"] = productID
        }
        logEvent("entitlement_state_changed", parameters: params)
    }

    // MARK: - Onboarding

    static func logOnboardingPageViewed(pageIndex: Int, pageID: String) {
        logEvent("onboarding_page_viewed", parameters: [
            "page_index": pageIndex,
            "page_id": pageID
        ])
    }

    static func logOnboardingCTATapped(pageIndex: Int, pageID: String) {
        logEvent("onboarding_cta_tapped", parameters: [
            "page_index": pageIndex,
            "page_id": pageID
        ])
    }

    // MARK: - Player setup

    static func logPlayerAdded(playerCount: Int) {
        logEvent("player_added", parameters: ["player_count": playerCount])
    }

    static func logPlayerRemoved(playerCount: Int) {
        logEvent("player_removed", parameters: ["player_count": playerCount])
    }

    static func logPlayerSetupContinueTapped(playerCount: Int) {
        logEvent("player_setup_continue_tapped", parameters: ["player_count": playerCount])
    }

    static func logPlayerSetupOptionsOpened() {
        logEvent("player_setup_options_opened")
    }

    // MARK: - Categories

    static func logCategorySelected(categoryName: String, isPremium: Bool) {
        logEvent("category_selected", parameters: [
            "category_name": categoryName,
            "is_premium": isPremium
        ])
    }

    static func logCategoryLockedTapped(categoryName: String) {
        logEvent("category_locked_tapped", parameters: ["category_name": categoryName])
    }

    static func logCategoryInfoOpened() {
        logEvent("category_info_opened")
    }

    static func logCategoryInfoStepViewed(stepIndex: Int) {
        logEvent("category_info_step_viewed", parameters: ["step_index": stepIndex])
    }

    static func logCategoriesPlayTapped(categoryName: String, playerCount: Int) {
        logEvent("categories_play_tapped", parameters: [
            "category_name": categoryName,
            "player_count": playerCount
        ])
    }

    static func logPremiumBannerTapped() {
        logEvent("premium_banner_tapped")
    }

    // MARK: - Custom AI word packs

    static func logCustomPackCreateOpened(existingPackCount: Int) {
        logEvent("custom_pack_create_opened", parameters: [
            "existing_pack_count": existingPackCount
        ])
    }

    static func logCustomPackLimitReached() {
        logEvent("custom_pack_limit_reached")
    }

    static func logCustomPackGenerateStarted(promptLength: Int) {
        logEvent("custom_pack_generate_started", parameters: [
            "prompt_length": promptLength
        ])
        setUserProperty("true", for: "has_used_custom_pack_ai")
    }

    static func logCustomPackGenerateSucceeded(categoryName: String, wordCount: Int, totalPackCount: Int) {
        logEvent("custom_pack_generate_succeeded", parameters: [
            "category_name": categoryName,
            "word_count": wordCount,
            "total_pack_count": totalPackCount
        ])
        setUserProperty(String(totalPackCount), for: "custom_pack_count")
    }

    static func logCustomPackGenerateFailed(reason: String) {
        logEvent("custom_pack_generate_failed", parameters: [
            "reason": reason
        ])
    }

    static func logCustomPackDeleted(categoryName: String, remainingPackCount: Int) {
        logEvent("custom_pack_deleted", parameters: [
            "category_name": categoryName,
            "remaining_pack_count": remainingPackCount
        ])
        setUserProperty(String(remainingPackCount), for: "custom_pack_count")
    }

    static func logCustomPackSelected(categoryName: String) {
        logEvent("custom_pack_selected", parameters: [
            "category_name": categoryName
        ])
    }

    // MARK: - Game settings

    static func logGameSettingsImposterCountChanged(value: Int) {
        logEvent("game_settings_imposter_count_changed", parameters: ["value": value])
    }

    static func logGameSettingsRoundDurationChanged(valueSeconds: Int) {
        logEvent("game_settings_round_duration_changed", parameters: ["value_seconds": valueSeconds])
    }

    static func logGameSettingsHintsToggled(enabled: Bool) {
        logEvent("game_settings_hints_toggled", parameters: ["enabled": enabled])
    }

    // MARK: - Role reveal

    static func logRoleRevealWordRevealed(playerIndex: Int, isImposter: Bool) {
        logEvent("role_reveal_word_revealed", parameters: [
            "player_index": playerIndex,
            "is_imposter": isImposter
        ])
    }

    static func logRoleRevealContinueTapped(playerIndex: Int, isLastPlayer: Bool) {
        logEvent("role_reveal_continue_tapped", parameters: [
            "player_index": playerIndex,
            "is_last_player": isLastPlayer
        ])
    }

    // MARK: - Game timer

    static func logGameTimerStarted(durationSeconds: Int) {
        logEvent("game_timer_started", parameters: ["duration_seconds": durationSeconds])
    }

    static func logGameTimerPaused() {
        logEvent("game_timer_paused")
    }

    static func logGameTimerResumed() {
        logEvent("game_timer_resumed")
    }

    static func logGameTimerVoteNowTapped() {
        logEvent("game_timer_vote_now_tapped")
    }

    static func logGameTimerExpired() {
        logEvent("game_timer_expired")
    }

    // MARK: - Voting

    static func logVotingSelectionChanged(selectedCount: Int, maxSelections: Int) {
        logEvent("voting_selection_changed", parameters: [
            "selected_count": selectedCount,
            "max_selections": maxSelections
        ])
    }

    static func logVotingRevealTapped(selectedCount: Int) {
        logEvent("voting_reveal_tapped", parameters: ["selected_count": selectedCount])
    }

    // MARK: - Result

    static func logResultPlayAgainTapped() {
        logEvent("result_play_again_tapped")
    }

    // MARK: - Language

    static func logLanguageChanged(from: String, to: String) {
        logEvent("language_changed", parameters: [
            "from_locale": from,
            "to_locale": to
        ])
    }

    // MARK: - Cohort-relevant user properties

    /// Current in-app language override — lets cohorts segment by locale.
    static func setAppLanguage(_ localeCode: String) {
        setUserProperty(localeCode, for: "app_language")
    }

    /// Bumps and persists the lifetime completed-game counter, then reflects it
    /// as a user property so cohorts can filter by engagement depth
    /// (e.g. "played >= 5 games").
    static func incrementTotalGamesPlayed() {
        let key = "com.imposter.analytics.totalGamesPlayed"
        let newCount = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(newCount, forKey: key)
        Analytics.setUserProperty(String(newCount), forName: "total_games_played")
        AmplitudeManager.setUserProperty(newCount, for: "total_games_played")
    }

    /// Last category played — lets cohorts segment by content preference.
    static func setLastCategoryPlayed(_ categoryName: String) {
        setUserProperty(categoryName, for: "last_category_played")
    }

    /// Outcome of the most recently completed round.
    static func setLastGameResult(_ result: String) {
        setUserProperty(result, for: "last_game_result")
    }
}

extension GameResult {
    var analyticsValue: String {
        switch self {
        case .playersWin: return "players_win"
        case .imposterWins: return "imposter_wins"
        }
    }
}
