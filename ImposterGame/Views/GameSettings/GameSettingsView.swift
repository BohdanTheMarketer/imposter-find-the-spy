import SwiftUI

struct GameSettingsView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var imposterCount: Int = 1
    @State private var roundDuration: Int = 120
    @State private var hintsEnabled: Bool = false
    @State private var showWordError = false

    private var maxImposters: Int {
        GameSettings.recommendedImposters(forPlayerCount: gameSession.players.count)
    }

    private var imposterCountLabel: String {
        let word = imposterCount == 1 ? "Imposter" : "Imposters"
        return "\(imposterCount) \(word)"
    }

    var body: some View {
        ZStack(alignment: .top) {
            gameSettingsBackground

            VStack(spacing: 0) {
                topHeader
                VStack(spacing: 14) {
                    impostersCard
                    roundDurationCard
                    hintsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        .safeAreaInset(edge: .bottom) {
            Button(action: {
                HapticsManager.impact(.heavy)
                gameSession.settings = GameSettings(
                    imposterCount: imposterCount,
                    roundDuration: roundDuration,
                    hintsEnabled: hintsEnabled
                )
                startGame()
            }) {
                HStack(spacing: 10) {
                    Text("PLAY")
                        .font(.evolventa(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("|")
                        .font(.evolventa(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                    Text(imposterCountLabel)
                        .font(.evolventa(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 26)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color.gameplayButtonPrimary)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .alert("Couldn't load a word for this category. Please try again.", isPresented: $showWordError) {
            Button("OK", role: .cancel) {}
        }
        .onAppear {
            imposterCount = maxImposters
            roundDuration = gameSession.settings.roundDuration
            hintsEnabled = gameSession.settings.hintsEnabled
        }
    }

    private var gameSettingsBackground: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()

            GridPatternView(lineColor: .white.opacity(0.10))
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private var topHeader: some View {
        HStack(spacing: 12) {
            Button(action: { router.pop() }) {
                Image(systemName: "chevron.left")
                    .font(.evolventa(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")

            Spacer()

            Text("Game Settings")
                .font(.evolventa(size: 30, weight: .bold))
                .foregroundColor(.gameplayTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Spacer()

            // Keep centered alignment.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var impostersCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Imposters")
                .font(.evolventa(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("How many players should be secret imposters?")
                .font(.evolventa(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .lineLimit(2)

            Text("Recommended for \(gameSession.players.count) players: \(maxImposters)")
                .font(.evolventa(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))

            HStack(spacing: 10) {
                stepperCircleButton(
                    icon: "minus",
                    disabled: imposterCount <= 1
                ) {
                    if imposterCount > 1 {
                        imposterCount -= 1
                        HapticsManager.selection()
                    }
                }

                Spacer()

                Text("\(imposterCount)")
                    .font(.evolventa(size: 46, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 70)

                Spacer()

                stepperCircleButton(
                    icon: "plus",
                    disabled: imposterCount >= maxImposters
                ) {
                    if imposterCount < maxImposters {
                        imposterCount += 1
                        HapticsManager.selection()
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(18)
        .cardShell()
    }

    private var roundDurationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Round Duration")
                .font(.evolventa(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("How long should each discussion round last?")
                .font(.evolventa(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .lineLimit(2)

            HStack(spacing: 10) {
                let currentIdx = GameSettings.durationOptions.firstIndex(of: roundDuration) ?? 0

                stepperCircleButton(
                    icon: "minus",
                    disabled: currentIdx <= 0
                ) {
                    if currentIdx > 0 {
                        roundDuration = GameSettings.durationOptions[currentIdx - 1]
                        HapticsManager.selection()
                    }
                }

                Spacer()

                Text(GameSettings.durationLabel(roundDuration))
                    .font(.evolventa(size: 46, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 120)

                Spacer()

                stepperCircleButton(
                    icon: "plus",
                    disabled: currentIdx >= GameSettings.durationOptions.count - 1
                ) {
                    if currentIdx < GameSettings.durationOptions.count - 1 {
                        roundDuration = GameSettings.durationOptions[currentIdx + 1]
                        HapticsManager.selection()
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(18)
        .cardShell()
    }

    private var hintsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hints for Imposters")
                .font(.evolventa(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Should imposters get a hint about the secret word?")
                .font(.evolventa(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .lineLimit(3)

            segmentedHintToggle
                .padding(.top, 4)
        }
        .padding(18)
        .cardShell()
    }

    private var segmentedHintToggle: some View {
        HStack(spacing: 0) {
            Button {
                // Only update if we're actually changing state.
                guard hintsEnabled else { return }
                hintsEnabled = false
                HapticsManager.selection()
            } label: {
                Text("Disabled")
                    .font(.evolventa(size: 12, weight: .bold))
                    .foregroundColor(hintsEnabled ? .white.opacity(0.55) : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(hintsEnabled ? Color.clear : Color.white)
            }

            Button {
                // Only update if we're actually changing state.
                guard !hintsEnabled else { return }
                hintsEnabled = true
                HapticsManager.selection()
            } label: {
                Text("Enabled")
                    .font(.evolventa(size: 12, weight: .bold))
                    .foregroundColor(hintsEnabled ? .black : .white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(hintsEnabled ? Color.white : Color.clear)
            }
        }
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private func stepperCircleButton(
        icon: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.evolventa(size: 26, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(Color.white.opacity(disabled ? 0.05 : 0.10))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(disabled ? 0.08 : 0.14), lineWidth: 1)
                )
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1.0)
    }

    private func startGame() {
        guard let category = gameSession.selectedCategory else { return }
        guard !gameSession.players.isEmpty else { return }

        // Persist settings on the shared session so later views (timer, role reveal) can read them.
        gameSession.settings = GameSettings(
            imposterCount: imposterCount,
            roundDuration: roundDuration,
            hintsEnabled: hintsEnabled
        )

        let engine = GameEngine()
        let word = engine.setupRound(
            players: &gameSession.players,
            category: category,
            imposterCount: imposterCount,
            hintsEnabled: hintsEnabled
        )

        guard !word.isEmpty && word != "Mystery" else {
            showWordError = true
            return
        }

        gameSession.secretWord = word
        gameSession.currentPlayerIndex = 0
        gameSession.startingPlayerIndex = engine.selectStartingPlayer(from: gameSession.players)
        gameSession.gamePhase = .roleReveal
        AnalyticsService.logGameStart(
            category: category.name,
            playerCount: gameSession.players.count,
            imposterCount: gameSession.settings.imposterCount
        )
        router.navigate(to: .roleReveal)
    }
}

private extension View {
    func cardShell() -> some View {
        self
            .background(Color.gameplaySurface)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 10)
    }
}
