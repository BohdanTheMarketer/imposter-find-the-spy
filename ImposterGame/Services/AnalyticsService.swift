import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsService {
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
}

extension GameResult {
    var analyticsValue: String {
        switch self {
        case .playersWin: return "players_win"
        case .imposterWins: return "imposter_wins"
        }
    }
}
