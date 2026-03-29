import Foundation

class GameEngine {
    private var usedWords: [String: Set<String>] = [:]

    func setupRound(
        players: inout [Player],
        category: Category,
        imposterCount: Int,
        hintsEnabled: Bool
    ) -> String {
        let word = pickUnusedWord(from: category)

        // Clamp imposter count to valid range
        let safeImposterCount = min(imposterCount, max(0, players.count - 1))

        let imposterIndices = Set(players.indices.shuffled().prefix(safeImposterCount))

        for i in players.indices {
            if imposterIndices.contains(i) {
                players[i].isImposter = true
                players[i].secretWord = hintsEnabled ? "Category: \(category.name)" : ""
            } else {
                players[i].isImposter = false
                players[i].secretWord = word
            }
        }

        return word
    }

    func selectStartingPlayer(from players: [Player]) -> Int {
        let nonImposters = players.indices.filter { !players[$0].isImposter }
        guard let selected = nonImposters.randomElement() else {
            // Fallback: pick any player (shouldn't happen with valid config)
            return players.indices.randomElement() ?? 0
        }
        return selected
    }

    func checkResult(votedPlayerIndex: Int, players: [Player]) -> GameResult {
        guard votedPlayerIndex >= 0, votedPlayerIndex < players.count else {
            return .imposterWins
        }
        if players[votedPlayerIndex].isImposter {
            return .playersWin
        } else {
            return .imposterWins
        }
    }

    func getImposters(from players: [Player]) -> [Player] {
        return players.filter { $0.isImposter }
    }

    private func pickUnusedWord(from category: Category) -> String {
        let categoryKey = category.name
        if usedWords[categoryKey] == nil {
            usedWords[categoryKey] = []
        }

        let available = category.words.filter { !usedWords[categoryKey]!.contains($0) }

        if available.isEmpty {
            usedWords[categoryKey] = []
            return category.words.randomElement() ?? "Mystery"
        }

        let word = available.randomElement() ?? "Mystery"
        usedWords[categoryKey]?.insert(word)
        return word
    }

    func resetUsedWords() {
        usedWords = [:]
    }
}
