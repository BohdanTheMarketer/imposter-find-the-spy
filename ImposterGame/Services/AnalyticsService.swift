import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

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

    static func logScreenView(for screen: AppScreen) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screen.rawValue,
            AnalyticsParameterScreenClass: screen.rawValue
        ])
        #endif
    }

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #endif
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
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: key)
        #endif
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

    static func logPurchaseStarted(source: String, context: PaywallContext?, plan: String, productID: String) {
        logEvent("purchase_started", parameters: [
            "source": source,
            "paywall_context": context?.rawValue ?? "unknown",
            "plan": plan,
            "product_id": productID
        ])
    }

    static func logPurchaseResult(
        source: String,
        context: PaywallContext?,
        plan: String,
        productID: String,
        result: String,
        errorCode: String? = nil
    ) {
        var params: [String: Any] = [
            "source": source,
            "paywall_context": context?.rawValue ?? "unknown",
            "plan": plan,
            "product_id": productID,
            "result": result
        ]
        if let errorCode {
            params["error_code"] = errorCode
        }
        logEvent("purchase_result", parameters: params)
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
}

extension GameResult {
    var analyticsValue: String {
        switch self {
        case .playersWin: return "players_win"
        case .imposterWins: return "imposter_wins"
        }
    }
}
