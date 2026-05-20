import Foundation

#if DEBUG

/// Seeds `GameSession` for App Store raw captures. Only used from `AppStoreScreenshotMenuView`.
enum AppStoreScreenshotSeeder {

    static func prepare(for screen: AppScreen, gameSession: GameSession) {
        switch screen {
        case .onboarding, .paywall, .categoryPaywall:
            gameSession.resetFull()

        case .playerSetup:
            seedPartyPlayers(gameSession)

        case .categories:
            seedPartyPlayers(gameSession)

        case .gameSettings:
            seedPartyPlayers(gameSession)
            if let category = pickDemoCategory() {
                gameSession.selectedCategory = category
            }
            gameSession.settings = GameSettings(imposterCount: 1, roundDuration: 120, hintsEnabled: false)

        case .roleReveal:
            seedPartyPlayers(gameSession)
            applyRoleRevealCrewFirst(gameSession)

        case .gameTimer:
            seedPartyPlayers(gameSession)
            applyRoleRevealCrewFirst(gameSession)
            gameSession.gamePhase = .playing
            gameSession.startingPlayerIndex = 0
            gameSession.settings.roundDuration = 120

        case .voting:
            seedPartyPlayers(gameSession)
            applyRoleRevealCrewFirst(gameSession)
            gameSession.gamePhase = .voting
            gameSession.settings.imposterCount = 1

        case .result:
            seedPartyPlayers(gameSession)
            applyRoleRevealCrewFirst(gameSession)
            gameSession.secretWord = "PIZZA"
            gameSession.gameResult = .playersWin
            gameSession.gamePhase = .result
        }
    }

    static func prepareRoleRevealImposterFirst(gameSession: GameSession) {
        seedPartyPlayers(gameSession)
        var players: [Player] = []
        var riley = Player(name: "Riley", avatarIndex: 2)
        riley.isImposter = true
        riley.secretWord = ""
        players.append(riley)
        for (name, av) in [("Alex", 0), ("Jordan", 1), ("Casey", 3), ("Sam", 4)] as [(String, Int)] {
            var p = Player(name: name, avatarIndex: av)
            p.isImposter = false
            p.secretWord = "PIZZA"
            players.append(p)
        }
        gameSession.players = players
        gameSession.secretWord = "PIZZA"
    }

    private static func seedPartyPlayers(_ gameSession: GameSession) {
        gameSession.resetFull()
        gameSession.players = [
            Player(name: "Alex", avatarIndex: 0),
            Player(name: "Jordan", avatarIndex: 1),
            Player(name: "Casey", avatarIndex: 3),
            Player(name: "Morgan", avatarIndex: 5),
            Player(name: "Sam", avatarIndex: 4)
        ]
    }

    private static func applyRoleRevealCrewFirst(_ gameSession: GameSession) {
        var players = gameSession.players
        guard !players.isEmpty else {
            seedPartyPlayers(gameSession)
            return applyRoleRevealCrewFirst(gameSession)
        }
        for i in players.indices {
            let isImposter = (i == players.count - 1)
            players[i].isImposter = isImposter
            players[i].secretWord = isImposter ? "" : "PIZZA"
        }
        gameSession.players = players
        gameSession.secretWord = "PIZZA"
        gameSession.settings.imposterCount = 1
        gameSession.gamePhase = .roleReveal
    }

    private static func pickDemoCategory() -> Category? {
        let all = CategoryLoader.loadCategories()
        return all.first(where: { !$0.isPremium }) ?? all.first
    }
}

#endif
