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
    /// Keep the "Moment of Truth" sequence intentionally dramatic and slow.
    private let intrigueSpeedMultiplier: Double = 4.0

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
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear,
                            outcomeAccentColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ResultAmbientGlowView(accent: outcomeAccentColor, secondary: Color.gameplayTitle.opacity(0.45))

            VStack(spacing: 0) {
                resultsHeader
                    .padding(.top, 20)
                    .padding(.bottom, 22)

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
                                Text("Play again")
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.evolventa(size: 17, weight: .semibold))
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
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .opacity(headerReveal ? 1 : 0)
                .scaleEffect(headerReveal ? 1 : 0.5)

            Text("Round complete")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.7))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
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
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.02),
                                outcomeAccentColor.opacity(0.1)
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
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.08),
                            outcomeAccentColor.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 12)
        .accessibilityElement(children: .combine)
    }

    private var outcomeHeroBlock: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(outcomeAccentColor.opacity(0.2))
                    .frame(width: 96, height: 96)
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.95))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                Image(systemName: didPlayersWin ? "trophy.fill" : "theatermasks.fill")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(headlineGradient)
            }
            .padding(.bottom, 4)

            Text(didPlayersWin ? "Players win" : "Imposter wins")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(headlineGradient)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)

            Text(didPlayersWin ? "The imposter was caught" : "Slipped away undetected")
                .font(.system(size: 17, weight: .medium, design: .rounded))
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
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                Text("Secret word")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(gameSession.secretWord)
                .font(.system(size: 30, weight: .bold, design: .rounded))
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
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.clear,
                                outcomeAccentColor.opacity(0.09)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Intrigue Sequence

    private func startIntrigueSequence() {
        let wordStep = 0.26 * intrigueSpeedMultiplier
        for i in 0..<intrigueTexts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * wordStep) {
                withAnimation(.easeInOut(duration: 0.2 * intrigueSpeedMultiplier)) {
                    intrigueTextIndex = i
                }
                HapticsManager.impact(i == intrigueTexts.count - 1 ? .medium : .light)
            }
        }

        let lastWordDelay = Double(intrigueTexts.count - 1) * wordStep
        let revealDelay = lastWordDelay + (0.28 * intrigueSpeedMultiplier)

        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
            withAnimation(.easeInOut(duration: 0.42)) {
                phase = .reveal
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.56, dampingFraction: 0.9)) {
                    headerReveal = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                if let result = gameSession.gameResult {
                    switch result {
                    case .playersWin:
                        HapticsManager.notification(.success)
                    case .imposterWins:
                        HapticsManager.notification(.warning)
                    }
                }
                withAnimation(.spring(response: 0.62, dampingFraction: 0.9)) {
                    showOutcomeSection = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.56, dampingFraction: 0.92)) {
                        outcomeCardAppeared = true
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
                withAnimation(.spring(response: 0.58, dampingFraction: 0.9)) {
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
