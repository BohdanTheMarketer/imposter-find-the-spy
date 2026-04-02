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
                if hintsEnabled {
                    players[i].secretWord = hint(for: word, in: category)
                } else {
                    players[i].secretWord = ""
                }
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

    func checkResult(votedPlayerIndices: [Int], players: [Player]) -> GameResult {
        guard !votedPlayerIndices.isEmpty else {
            return .imposterWins
        }

        let uniqueIndices = Array(Set(votedPlayerIndices))
        guard uniqueIndices.allSatisfy({ $0 >= 0 && $0 < players.count }) else {
            return .imposterWins
        }

        let actualImposterIndices = Set(players.indices.filter { players[$0].isImposter })
        if Set(uniqueIndices) == actualImposterIndices {
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

    private func hint(for word: String, in category: Category) -> String {
        if let index = category.words.firstIndex(of: word), index < category.imposterHints.count {
            let hint = category.imposterHints[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !hint.isEmpty {
                return hint
            }
        }

        // Keep a deterministic fallback if hints are missing or out of sync.
        return "Category: \(category.name)"
    }
}
