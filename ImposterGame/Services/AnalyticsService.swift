import FirebaseAnalytics
import Foundation

enum AnalyticsService {
    static func logScreenView(for screen: AppScreen) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screen.rawValue,
            AnalyticsParameterScreenClass: screen.rawValue
        ])
    }

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
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
