import Foundation

struct GameSettings {
    var imposterCount: Int = 1
    var roundDuration: Int = 120 // seconds
    var hintsEnabled: Bool = false

    var maxImposters: Int {
        return 3
    }

    func maxImposters(forPlayerCount count: Int) -> Int {
        return max(1, count / 3)
    }

    var formattedDuration: String {
        let minutes = roundDuration / 60
        let seconds = roundDuration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static let durationOptions = [60, 120, 180, 300]

    static func durationLabel(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs == 0 {
            return "\(minutes):00"
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
