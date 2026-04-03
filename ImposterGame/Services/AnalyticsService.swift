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
}

extension GameResult {
    var analyticsValue: String {
        switch self {
        case .playersWin: return "players_win"
        case .imposterWins: return "imposter_wins"
        }
    }
}
