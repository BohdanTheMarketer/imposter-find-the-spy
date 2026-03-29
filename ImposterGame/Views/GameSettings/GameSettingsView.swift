import SwiftUI

struct GameSettingsView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var imposterCount: Int = 1
    @State private var roundDuration: Int = 120
    @State private var hintsEnabled: Bool = false

    private var maxImposters: Int {
        guard gameSession.players.count >= 3 else { return 1 }
        return max(1, gameSession.players.count / 3)
    }

    var body: some View {
        ZStack {
            // Red gradient background with grid
            LinearGradient.appRedGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { router.pop() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Game Settings")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Imposters setting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Imposters")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("How many players should be secret imposters?")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))

                            Text("Recommended for \(gameSession.players.count) players: \(maxImposters > 1 ? "1-\(maxImposters)" : "1")")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))

                            // Stepper
                            HStack {
                                Spacer()
                                Button(action: {
                                    if imposterCount > 1 {
                                        imposterCount -= 1
                                        HapticsManager.selection()
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .opacity(imposterCount > 1 ? 1.0 : 0.3)
                                .disabled(imposterCount <= 1)

                                Text("\(imposterCount)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 60)

                                Button(action: {
                                    if imposterCount < maxImposters {
                                        imposterCount += 1
                                        HapticsManager.selection()
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .opacity(imposterCount < maxImposters ? 1.0 : 0.3)
                                .disabled(imposterCount >= maxImposters)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                        .cardStyle()

                        // Round Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Round Duration")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("How long should each discussion round last?")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))

                            HStack {
                                Spacer()

                                let currentIdx = GameSettings.durationOptions.firstIndex(of: roundDuration) ?? 1

                                Button(action: {
                                    if currentIdx > 0 {
                                        roundDuration = GameSettings.durationOptions[currentIdx - 1]
                                        HapticsManager.selection()
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .opacity(currentIdx > 0 ? 1.0 : 0.3)
                                .disabled(currentIdx <= 0)

                                Text(GameSettings.durationLabel(roundDuration))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 80)

                                Button(action: {
                                    if currentIdx < GameSettings.durationOptions.count - 1 {
                                        roundDuration = GameSettings.durationOptions[currentIdx + 1]
                                        HapticsManager.selection()
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .opacity(currentIdx < GameSettings.durationOptions.count - 1 ? 1.0 : 0.3)
                                .disabled(currentIdx >= GameSettings.durationOptions.count - 1)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                        .cardStyle()

                        // Hints for Imposters
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hints for Imposters")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("Should imposters get a hint about the secret word?")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))

                            HStack(spacing: 0) {
                                Button(action: {
                                    hintsEnabled = false
                                    HapticsManager.selection()
                                }) {
                                    Text("Disabled")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(!hintsEnabled ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                Button(action: {
                                    hintsEnabled = true
                                    HapticsManager.selection()
                                }) {
                                    Text("Enabled")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(hintsEnabled ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .cardStyle()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }

                Spacer()

                // Play button
                Button(action: {
                    HapticsManager.impact(.heavy)
                    gameSession.settings = GameSettings(
                        imposterCount: imposterCount,
                        roundDuration: roundDuration,
                        hintsEnabled: hintsEnabled
                    )
                    startGame()
                }) {
                    HStack(spacing: 12) {
                        Text("PLAY")
                            .font(.system(size: 22, weight: .black))

                        Text("|")
                            .foregroundColor(.white.opacity(0.3))

                        Text("\(imposterCount) Imposter\(imposterCount > 1 ? "s" : "")")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            imposterCount = min(imposterCount, maxImposters)
        }
    }

    private func startGame() {
        guard let category = gameSession.selectedCategory else { return }
        guard !gameSession.players.isEmpty else { return }

        let engine = GameEngine()
        let word = engine.setupRound(
            players: &gameSession.players,
            category: category,
            imposterCount: imposterCount,
            hintsEnabled: hintsEnabled
        )
        gameSession.secretWord = word
        gameSession.currentPlayerIndex = 0
        gameSession.startingPlayerIndex = engine.selectStartingPlayer(from: gameSession.players)
        gameSession.gamePhase = .roleReveal
        router.navigate(to: .roleReveal)
    }
}
