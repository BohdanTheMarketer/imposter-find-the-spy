import SwiftUI

struct ResultView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var phase: ResultPhase = .intrigue
    @State private var intrigueTextIndex = 0
    @State private var showOutcomeSection = false
    @State private var showActionButtons = false
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

    private var outcomeTitle: String {
        didPlayersWin ? "VICTORY!" : "IMPOSTER WINS"
    }

    private var outcomeSubtitle: String {
        didPlayersWin ? "The imposter was caught" : "They slipped away undetected"
    }

    private var headlineGradient: LinearGradient {
        if didPlayersWin {
            LinearGradient(
                colors: [
                    Color.revealGreen,
                    Color.appAccentHigh
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [
                    Color.revealOrange,
                    Color.appAccentHigh
                ],
                startPoint: .top,
                endPoint: .bottom
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
            showActionButtons = false
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

            ResultConfettiView(
                accent: outcomeAccentColor,
                secondary: didPlayersWin ? .appAccentHigh : .revealPurple
            )
            .allowsHitTesting(false)

            ResultAmbientGlowView(accent: outcomeAccentColor, secondary: Color.revealPurple.opacity(0.8))

            VStack(spacing: 0) {
                resultsHeader
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                if showOutcomeSection {
                    outcomeCard
                        .scaleEffect(outcomeCardAppeared ? 1 : 0.92)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 24)),
                                removal: .opacity
                            )
                        )
                        .padding(.horizontal, 20)
                } else {
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showActionButtons {
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
                            Text("New game")
                                .font(.evolventa(size: 17, weight: .semibold))
                                .foregroundColor(.white.opacity(0.76))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.appSurface2)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: showActionButtons)
    }

    private var resultsHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(outcomeAccentColor)
                .opacity(headerReveal ? 1 : 0)
                .scaleEffect(headerReveal ? 1 : 0.5)

            Text("Round complete")
                .font(.evolventa(size: 12, weight: .bold))
                .foregroundColor(outcomeAccentColor)
                .textCase(.uppercase)
                .tracking(1.1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(outcomeAccentColor.opacity(0.14))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(outcomeAccentColor.opacity(0.45), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .offset(y: headerReveal ? 0 : -12)
        .opacity(headerReveal ? 1 : 0)
    }

    private var outcomeCard: some View {
        VStack(spacing: 0) {
            outcomeHeroBlock

            Text(imposters.count > 1 ? "The imposters" : "The imposter")
                .font(.evolventa(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(1.1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
                .padding(.bottom, 10)

            imposterRevealSection
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var outcomeHeroBlock: some View {
        VStack(spacing: 12) {
            ZStack {
                ResultBurstRaysView(primary: outcomeAccentColor, secondary: Color.appAccent)
                    .frame(width: 170, height: 170)
                    .opacity(0.5)

                Circle()
                    .fill(outcomeAccentColor.opacity(0.25))
                    .frame(width: 120, height: 120)
                    .blur(radius: 12)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [outcomeAccentColor, Color.appSurface2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)
                    .overlay(
                        Circle()
                            .stroke(outcomeAccentColor.opacity(0.9), lineWidth: 2)
                    )

                Image(systemName: didPlayersWin ? "trophy.fill" : "theatermasks.fill")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.62))
            }
            .padding(.top, 2)
            .padding(.bottom, 6)

            Text(outcomeTitle)
                .font(.evolventa(size: 44, weight: .bold))
                .foregroundStyle(headlineGradient)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
                .tracking(-1.2)

            Text(outcomeSubtitle)
                .font(.evolventa(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var imposterRevealSection: some View {
        if imposters.isEmpty {
            Text("No imposter found")
                .font(.evolventa(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if imposters.count == 1, let imposter = imposters.first {
            HStack(spacing: 14) {
                PlayerAvatarThumbnailView(
                    avatarIndex: imposter.avatarIndex,
                    size: 64,
                    cornerRadius: 18
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(imposter.name)
                        .font(.evolventa(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                        Text("word was \(gameSession.secretWord)")
                            .font(.evolventa(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        } else {
            LazyVGrid(columns: imposterGridColumns, spacing: 18) {
                ForEach(Array(imposters.enumerated()), id: \.element.id) { index, imposter in
                    imposterCell(imposter: imposter, size: 96, corner: 16, index: index)
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
                    showActionButtons = true
                }
                HapticsManager.selection()
            }
        }
    }
}

// MARK: - Ambient background

private struct ResultConfettiView: View {
    let accent: Color
    let secondary: Color
    private let pieces: [ConfettiPiece] = (0..<34).map { index in
        let x = Double((index * 29) % 100) / 100.0
        let delay = Double((index * 7) % 24) / 10.0
        let duration = 3.2 + Double((index * 11) % 18) / 10.0
        let size = CGFloat(6 + (index % 7))
        let drift = CGFloat((index % 5) * 12) - 24
        return ConfettiPiece(id: index, x: x, delay: delay, duration: duration, size: size, drift: drift)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.id.isMultiple(of: 2) ? accent : secondary)
                        .frame(width: piece.id.isMultiple(of: 3) ? piece.size * 0.45 : piece.size, height: piece.size)
                        .position(x: geo.size.width * piece.x, y: -12)
                        .opacity(0.82)
                        .modifier(
                            FallingConfettiAnimation(
                                delay: piece.delay,
                                duration: piece.duration,
                                dropDistance: geo.size.height + 90,
                                drift: piece.drift
                            )
                        )
                }
            }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let x: Double
    let delay: Double
    let duration: Double
    let size: CGFloat
    let drift: CGFloat
}

private struct FallingConfettiAnimation: ViewModifier {
    let delay: Double
    let duration: Double
    let dropDistance: CGFloat
    let drift: CGFloat
    @State private var animate = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(animate ? 280 : 0))
            .offset(x: animate ? drift : 0, y: animate ? dropDistance : -10)
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false).delay(delay)) {
                    animate = true
                }
            }
    }
}

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

private struct ResultBurstRaysView: View {
    let primary: Color
    let secondary: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((date.truncatingRemainder(dividingBy: 24)) / 24 * 360)

            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index.isMultiple(of: 2) ? primary.opacity(0.4) : secondary.opacity(0.25))
                        .frame(width: 4, height: 68)
                        .offset(y: -52)
                        .rotationEffect(.degrees(Double(index) * 30))
                }
            }
            .rotationEffect(angle)
        }
    }
}
