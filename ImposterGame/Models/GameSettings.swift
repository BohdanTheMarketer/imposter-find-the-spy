import Foundation

struct GameSettings {
    var imposterCount: Int = 1
    var roundDuration: Int = 120 // seconds
    var hintsEnabled: Bool = false

    var maxImposters: Int {
        // Historical default; the real recommendation is based on player count.
        return Self.recommendedImposters(forPlayerCount: 3)
    }

    /// Recommended/max number of imposters based on the total player count.
    ///
    /// Rules (per spec):
    /// - 3-5 players  -> 1
    /// - 6-8 players  -> 2
    /// - 9-11 players -> 3
    /// - 12-13 players-> 3
    /// - 14-15 players-> 4
    static func recommendedImposters(forPlayerCount count: Int) -> Int {
        switch count {
        case 3...5:
            return 1
        case 6...8:
            return 2
        case 9...13:
            return 3
        case 14...15:
            return 4
        default:
            // Keep the configuration safe even if called with unexpected values.
            if count <= 5 { return 1 }
            if count <= 8 { return 2 }
            if count <= 13 { return 3 }
            return 4
        }
    }

    func maxImposters(forPlayerCount count: Int) -> Int {
        Self.recommendedImposters(forPlayerCount: count)
    }

    var formattedDuration: String {
        let minutes = roundDuration / 60
        let seconds = roundDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // All 30-second increments between 30s and 300s (inclusive).
    static let durationOptions = [30, 60, 90, 120, 150, 180, 210, 240, 270, 300]

    static func durationLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(minutes):00"
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
