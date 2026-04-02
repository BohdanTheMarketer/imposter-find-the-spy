import Foundation
import SwiftUI

enum GamePhase {
    case setup
    case roleReveal
    case playing
    case paused
    case voting
    case result
}

enum GameResult {
    case playersWin
    case imposterWins
}

class GameSession: ObservableObject {
    @Published var players: [Player] = []
    @Published var selectedCategory: Category?
    @Published var settings: GameSettings = .init()
    @Published var currentPlayerIndex: Int = 0
    @Published var gamePhase: GamePhase = .setup
    @Published var secretWord: String = ""
    @Published var votedPlayerIndices: [Int] = []
    @Published var gameResult: GameResult?
    @Published var startingPlayerIndex: Int = 0

    func resetForNewRound() {
        currentPlayerIndex = 0
        gamePhase = .setup
        selectedCategory = nil
        votedPlayerIndices = []
        gameResult = nil
        for i in players.indices {
            players[i].isImposter = false
            players[i].secretWord = ""
        }
    }

    func resetFull() {
        players = []
        selectedCategory = nil
        settings = .init()
        resetForNewRound()
    }
}
