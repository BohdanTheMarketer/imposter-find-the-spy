import SwiftUI

struct ResultView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var phase: ResultPhase = .intrigue
    @State private var intrigueTextIndex = 0
    @State private var showContent = false

    enum ResultPhase {
        case intrigue
        case reveal
    }

    private let intrigueTexts = ["THE", "MOMENT", "OF", "TRUTH"]

    private var didPlayersWin: Bool {
        gameSession.gameResult == .playersWin
    }

    private var imposters: [Player] {
        gameSession.players.filter { $0.isImposter }
    }

    var body: some View {
        ZStack {
            if phase == .intrigue {
                intrigueView
            } else {
                resultRevealView
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Reset state for fresh animation
            phase = .intrigue
            intrigueTextIndex = 0
            showContent = false
            if let result = gameSession.gameResult {
                AnalyticsService.logEvent("round_result", parameters: ["outcome": result.analyticsValue])
            }
            startIntrigueSequence()
        }
    }

    // MARK: - Intrigue View
    private var intrigueView: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.05)
                )

            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<intrigueTexts.count, id: \.self) { index in
                    if index <= intrigueTextIndex {
                        Text(intrigueTexts[index])
                            .font(.evolventa(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Result Reveal
    private var resultRevealView: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                Text("Results")
                    .font(.evolventa(size: 28, weight: .bold))
                    .foregroundColor(.gameplayTitle)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                if showContent {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Win/Lose card
                            VStack(spacing: 12) {
                                if didPlayersWin {
                                    Text("Players Win!")
                                        .font(.evolventa(size: 28, weight: .bold))
                                        .foregroundColor(.white)

                                    Text("The imposter was caught!")
                                        .font(.evolventa(size: 15))
                                        .foregroundColor(.white.opacity(0.7))
                                } else {
                                    Text("Imposter Wins!")
                                        .font(.evolventa(size: 28, weight: .bold))
                                        .foregroundColor(.white)

                                    Text("The imposter got away undetected")
                                        .font(.evolventa(size: 15))
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                // Show the imposter(s)
                                ForEach(imposters) { imposter in
                                    VStack(spacing: 8) {
                                        PlayerAvatarThumbnailView(
                                            avatarIndex: imposter.avatarIndex,
                                            size: 120,
                                            cornerRadius: 16
                                        )

                                        Text(imposter.name)
                                            .font(.evolventa(size: 16, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color.gameplaySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            // Secret word card
                            VStack(spacing: 8) {
                                Text("Secret Word")
                                    .font(.evolventa(size: 14))
                                    .foregroundColor(.white.opacity(0.6))

                                Text(gameSession.secretWord)
                                    .font(.evolventa(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.7)
                                    .lineLimit(2)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color.gameplaySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer()

                // Buttons
                if showContent {
                    Button(action: {
                        HapticsManager.impact(.medium)
                        gameSession.resetForNewRound()
                        router.navigateToCategories()
                    }) {
                        HStack(spacing: 8) {
                            Text("PLAY AGAIN")
                                .font(.evolventa(size: 20, weight: .bold))
                            Image(systemName: "arrow.counterclockwise")
                                .font(.evolventa(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gameplayButtonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Intrigue Sequence
    private func startIntrigueSequence() {
        for i in 0..<intrigueTexts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    intrigueTextIndex = i
                }
                HapticsManager.impact(.heavy)
            }
        }

        // Transition to result after intrigue
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = .reveal
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
            }
        }
    }
}
