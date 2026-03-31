import SwiftUI

struct GameSettingsView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var imposterCount: Int = 1
    @State private var roundDuration: Int = 120
    @State private var hintsEnabled: Bool = false
    @State private var mysteryTwistEnabled: Bool = true

    private var maxImposters: Int {
        guard gameSession.players.count >= 3 else { return 1 }
        return max(1, gameSession.players.count / 3)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.055, green: 0.051, blue: 0.082)
                .ignoresSafeArea()
            backgroundOrbs

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Configure Your Lobby")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white)
                        Text("Fine-tune the gameplay mechanics before starting the session.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Imposters")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                Text("How many players should be secret imposters?")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.62))
                                Text("Recommended for \(gameSession.players.count) players: \(maxImposters > 1 ? "1-\(maxImposters)" : "1")")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.60))
                                .frame(width: 44, height: 44)
                                .background(Color(red: 1.0, green: 0.55, blue: 0.60).opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 1.0, green: 0.55, blue: 0.60).opacity(0.35), lineWidth: 1)
                                )
                        }

                        HStack {
                            Spacer()
                            stepperButton(icon: "minus", disabled: imposterCount <= 1) {
                                if imposterCount > 1 {
                                    imposterCount -= 1
                                    HapticsManager.selection()
                                }
                            }

                            Text("\(imposterCount)")
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 70)
                                .padding(.horizontal, 18)

                            stepperButton(icon: "plus", disabled: imposterCount >= maxImposters) {
                                if imposterCount < maxImposters {
                                    imposterCount += 1
                                    HapticsManager.selection()
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                    .glassCardStyle()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Round Duration")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                Text("How long should each discussion round last?")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.62))
                            }
                            Spacer()
                            Image(systemName: "clock.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.60))
                                .frame(width: 44, height: 44)
                                .background(Color(red: 1.0, green: 0.55, blue: 0.60).opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(red: 1.0, green: 0.55, blue: 0.60).opacity(0.35), lineWidth: 1)
                                )
                        }

                        HStack {
                            Spacer()

                            let currentIdx = GameSettings.durationOptions.firstIndex(of: roundDuration) ?? 1

                            stepperButton(icon: "minus", disabled: currentIdx <= 0) {
                                if currentIdx > 0 {
                                    roundDuration = GameSettings.durationOptions[currentIdx - 1]
                                    HapticsManager.selection()
                                }
                            }

                            Text(GameSettings.durationLabel(roundDuration))
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 120)
                                .padding(.horizontal, 6)

                            stepperButton(icon: "plus", disabled: currentIdx >= GameSettings.durationOptions.count - 1) {
                                if currentIdx < GameSettings.durationOptions.count - 1 {
                                    roundDuration = GameSettings.durationOptions[currentIdx + 1]
                                    HapticsManager.selection()
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                    .glassCardStyle()

                    HStack(spacing: 14) {
                        toggleTile(
                            title: "Mystery Twist",
                            subtitle: "Adds random events during play",
                            icon: "sparkles",
                            isOn: mysteryTwistEnabled
                        ) {
                            mysteryTwistEnabled.toggle()
                            HapticsManager.selection()
                        }

                        toggleTile(
                            title: "Hints for Imposters",
                            subtitle: "Assists the hidden players",
                            icon: "brain.head.profile",
                            isOn: hintsEnabled
                        ) {
                            hintsEnabled.toggle()
                            HapticsManager.selection()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("PRO TIP")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                        Text("Lower round durations increase intensity and favor the imposters.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.05, blue: 0.34),
                                Color(red: 0.90, green: 0.00, blue: 0.29),
                                Color(red: 0.43, green: 0.00, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 20)
                .padding(.top, 72)
                .padding(.bottom, 120)
            }

            HStack {
                Button(action: { router.pop() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .zIndex(1)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(Array(gameSession.players.prefix(3).enumerated()), id: \.offset) { index, _ in
                        Circle()
                            .fill(AvatarColors.color(for: index))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    if gameSession.players.count > 3 {
                        Text("+\(gameSession.players.count - 3)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.60))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.leading, 6)

                Spacer()

                Button(action: {
                    HapticsManager.impact(.heavy)
                    gameSession.settings = GameSettings(
                        imposterCount: imposterCount,
                        roundDuration: roundDuration,
                        hintsEnabled: hintsEnabled
                    )
                    startGame()
                }) {
                    HStack(spacing: 8) {
                        Text("PLAY")
                            .font(.system(size: 20, weight: .black))
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .black))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.28))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            imposterCount = min(imposterCount, maxImposters)
        }
    }

    private func stepperButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Color.white.opacity(0.07))
                .overlay(
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .opacity(disabled ? 0.35 : 1.0)
        .disabled(disabled)
    }

    private var backgroundOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.0, blue: 0.45).opacity(0.30))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -140, y: -250)

            Circle()
                .fill(Color(red: 0.22, green: 0.50, blue: 1.0).opacity(0.26))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 150, y: -130)

            Circle()
                .fill(Color(red: 0.45, green: 0.0, blue: 1.0).opacity(0.24))
                .frame(width: 340, height: 340)
                .blur(radius: 95)
                .offset(x: 40, y: 240)
        }
        .ignoresSafeArea()
    }

    private func toggleTile(title: String, subtitle: String, icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.60).opacity(0.9))
            }

            HStack(spacing: 0) {
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(4)
            .background(Color.black.opacity(0.35))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .top)
        .padding(14)
        .glassCardStyle()
        .onTapGesture(perform: action)
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

private extension View {
    func glassCardStyle() -> some View {
        self
            .padding(16)
            .background(Color(red: 0.10, green: 0.095, blue: 0.135).opacity(0.84))
            .background(.ultraThinMaterial.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
}
