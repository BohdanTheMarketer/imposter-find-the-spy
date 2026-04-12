import SwiftUI

struct ResultView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var phase: ResultPhase = .intrigue
    @State private var intrigueTextIndex = 0
    @State private var showOutcomeSection = false
    @State private var showSecretSection = false
    @State private var headerReveal = false
    @State private var outcomeCardAppeared = false

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

    private var outcomeAccentColor: Color {
        didPlayersWin ? Color.revealGreen : Color.revealOrange
    }

    private var headlineGradient: LinearGradient {
        if didPlayersWin {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.revealGreen.opacity(0.92),
                    Color(red: 0.45, green: 0.95, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.revealOrange,
                    Color(red: 1.0, green: 0.42, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var imposterGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
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
            phase = .intrigue
            intrigueTextIndex = 0
            showOutcomeSection = false
            showSecretSection = false
            headerReveal = false
            outcomeCardAppeared = false
            if let result = gameSession.gameResult {
                AnalyticsService.logGameEnd(
                    result: result.analyticsValue,
                    duration: gameSession.settings.roundDuration
                )
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

            VStack {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<intrigueTexts.count, id: \.self) { index in
                        if index <= intrigueTextIndex {
                            Text(intrigueTexts[index])
                                .font(.evolventa(size: 48, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.88)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.gameplayTitle.opacity(0.35), radius: 18, x: 0, y: 0)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.92)).combined(with: .move(edge: .leading)),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Result Reveal

    private var resultRevealView: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()

            ResultAmbientGlowView(accent: outcomeAccentColor, secondary: Color.gameplayTitle.opacity(0.45))

            GridPatternView()
                .opacity(0.08)

            VStack(spacing: 0) {
                resultsHeader
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if showOutcomeSection {
                            outcomeCard
                                .scaleEffect(outcomeCardAppeared ? 1 : 0.92)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 24)),
                                        removal: .opacity
                                    )
                                )
                        }
                        if showSecretSection {
                            secretWordCard
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 18)).combined(with: .scale(scale: 0.98)),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showSecretSection {
                    VStack(spacing: 10) {
                        Button(action: {
                            HapticsManager.impact(.medium)
                            gameSession.resetForNewRound()
                            router.navigateToCategories()
                        }) {
                            HStack(spacing: 10) {
                                Text("PLAY AGAIN")
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .buttonStyle(GameplayPrimaryButtonStyle())

                        Button(action: {
                            HapticsManager.impact(.light)
                            gameSession.resetForNewRound()
                            router.navigateToPlayerSetup()
                        }) {
                            Text("New Game")
                                .font(.evolventa(size: 17, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: showSecretSection)
    }

    private var resultsHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.gameplayTitle, Color.gameplayTitle.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(headerReveal ? 1 : 0)
                .scaleEffect(headerReveal ? 1 : 0.5)

            Text("Round complete")
                .font(.evolventa(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
        .offset(y: headerReveal ? 0 : -12)
        .opacity(headerReveal ? 1 : 0)
    }

    private var outcomeCard: some View {
        VStack(spacing: 0) {
            outcomeHeroBlock

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            outcomeAccentColor.opacity(0),
                            outcomeAccentColor.opacity(0.45),
                            outcomeAccentColor.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.vertical, 18)

            Text(imposters.count > 1 ? "The imposters" : "The imposter")
                .font(.evolventa(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(1.1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)

            imposterRevealSection
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.gameplaySurface)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                outcomeAccentColor.opacity(0.14),
                                outcomeAccentColor.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            outcomeAccentColor.opacity(0.65),
                            outcomeAccentColor.opacity(0.2),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: outcomeAccentColor.opacity(0.22), radius: 28, x: 0, y: 14)
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }

    private var outcomeHeroBlock: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(outcomeAccentColor.opacity(0.2))
                    .frame(width: 88, height: 88)
                    .blur(radius: 12)
                Circle()
                    .stroke(outcomeAccentColor.opacity(0.35), lineWidth: 1)
                    .frame(width: 76, height: 76)
                Image(systemName: didPlayersWin ? "trophy.fill" : "theatermasks.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(headlineGradient)
            }
            .padding(.bottom, 4)

            Text(didPlayersWin ? "Players win" : "Imposter wins")
                .font(.evolventa(size: 32, weight: .bold))
                .foregroundStyle(headlineGradient)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)

            Text(didPlayersWin ? "The imposter was caught" : "Slipped away undetected")
                .font(.evolventa(size: 16))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var imposterRevealSection: some View {
        if imposters.count <= 1 {
            ForEach(Array(imposters.enumerated()), id: \.element.id) { index, imposter in
                imposterCell(imposter: imposter, size: 124, corner: 20, index: index)
            }
        } else {
            LazyVGrid(columns: imposterGridColumns, spacing: 18) {
                ForEach(Array(imposters.enumerated()), id: \.element.id) { index, imposter in
                    imposterCell(imposter: imposter, size: 104, corner: 18, index: index)
                }
            }
        }
    }

    private func imposterCell(imposter: Player, size: CGFloat, corner: CGFloat, index: Int) -> some View {
        VStack(spacing: 10) {
            PlayerAvatarThumbnailView(
                avatarIndex: imposter.avatarIndex,
                size: size,
                cornerRadius: corner
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [outcomeAccentColor.opacity(0.5), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

            Text(imposter.name)
                .font(.evolventa(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))
        }
        .opacity(showOutcomeSection ? 1 : 0)
        .scaleEffect(showOutcomeSection ? 1 : 0.88)
        .offset(y: showOutcomeSection ? 0 : 12)
        .animation(
            .spring(response: 0.48, dampingFraction: 0.78)
                .delay(Double(index) * 0.11),
            value: showOutcomeSection
        )
    }

    private var secretWordCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                Text("Secret word")
                    .font(.evolventa(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            Text(gameSession.secretWord)
                .font(.evolventa(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color.white.opacity(0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .padding(.top, 2)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.gameplaySurface.opacity(0.92))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.gameplayTitle.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Intrigue Sequence

    private func startIntrigueSequence() {
        let wordStep = 0.26
        for i in 0..<intrigueTexts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * wordStep) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    intrigueTextIndex = i
                }
                HapticsManager.impact(i == intrigueTexts.count - 1 ? .medium : .light)
            }
        }

        let lastWordDelay = Double(intrigueTexts.count - 1) * wordStep
        let revealDelay = lastWordDelay + 0.28

        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
            withAnimation(.easeInOut(duration: 0.38)) {
                phase = .reveal
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    headerReveal = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                if let result = gameSession.gameResult {
                    switch result {
                    case .playersWin:
                        HapticsManager.notification(.success)
                    case .imposterWins:
                        HapticsManager.notification(.warning)
                    }
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    showOutcomeSection = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                        outcomeCardAppeared = true
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    showSecretSection = true
                }
                HapticsManager.selection()
            }
        }
    }
}

// MARK: - Ambient background

private struct ResultAmbientGlowView: View {
    let accent: Color
    let secondary: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 28, y: -36)
            Circle()
                .fill(secondary.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 55)
                .offset(x: -36, y: 44)
            Circle()
                .fill(Color.revealPurple.opacity(0.1))
                .frame(width: 180, height: 180)
                .blur(radius: 45)
                .offset(x: 22, y: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
