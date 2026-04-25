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

    private var frameColor: Color {
        didPlayersWin ? Color.onboardingGreen : Color.onboardingRed
    }

    private var outcomeTitle: String {
        didPlayersWin ? "Players Win!" : "Imposter Wins!"
    }

    private var outcomeSubtitle: String {
        if didPlayersWin {
            if imposters.count <= 1 { return "The imposter was caught" }
            if imposters.count == 2 { return "Both imposters caught" }
            return "All \(imposters.count) imposters caught"
        }
        return "They got away undetected"
    }

    private var resultBadgeText: String {
        didPlayersWin ? "Players won" : "Imposter won"
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
            frameColor
                .ignoresSafeArea()
                .overlay(GridPatternView().opacity(0.08))

            if showOutcomeSection {
                resultFullscreenLayout
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: showActionButtons)
    }

    private var resultFullscreenLayout: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                Text("Results")
                    .font(.evolventa(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 12) {
                    Text(outcomeTitle)
                        .font(.evolventa(size: 50, weight: .bold))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .foregroundColor(.white)

                    Text(outcomeSubtitle)
                        .font(.evolventa(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .multilineTextAlignment(.center)

                    imposterGridSection
                }
                .padding(.top, 12)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
                .background(Color.appBackground.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if !gameSession.secretWord.isEmpty {
                    VStack(spacing: 6) {
                        Text("SECRET WORD")
                            .font(.evolventa(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                            .tracking(1.1)

                        Text(gameSession.secretWord)
                            .font(.evolventa(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.appBackground.opacity(0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                Spacer(minLength: 0)

                Group {
                    if showActionButtons {
                        Button(action: {
                            HapticsManager.impact(.medium)
                            gameSession.resetForNewRound()
                            router.navigateToCategories()
                        }) {
                            HStack(spacing: 10) {
                                Text("PLAY AGAIN")
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, max(geo.safeAreaInsets.bottom + 10, 18))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var imposterGridSection: some View {
        if imposters.isEmpty {
            Text("No imposter found")
                .font(.evolventa(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .center)
        } else if imposters.count == 1, let imposter = imposters.first {
            HStack {
                Spacer()
                imposterTile(imposter: imposter, size: 124)
                Spacer()
            }
        } else {
            VStack(spacing: 12) {
                let firstRowCount = min(2, imposters.count)
                HStack(spacing: 12) {
                    ForEach(0..<firstRowCount, id: \.self) { idx in
                        imposterTile(imposter: imposters[idx], size: 108)
                    }
                }
                if imposters.count > 2 {
                    if imposters.count == 3 {
                        HStack {
                            Spacer()
                            imposterTile(imposter: imposters[2], size: 108)
                            Spacer()
                        }
                    } else {
                        HStack(spacing: 12) {
                            ForEach(2..<min(4, imposters.count), id: \.self) { idx in
                                imposterTile(imposter: imposters[idx], size: 108)
                            }
                        }
                    }
                }
            }
        }
    }

    private func imposterTile(imposter: Player, size: CGFloat) -> some View {
        VStack(spacing: 8) {
            PlayerAvatarSquareTileView(
                avatarIndex: imposter.avatarIndex,
                cornerRadius: 18
            )
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)

            Text(imposter.name)
                .font(.evolventa(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gameplaySurface)
        )
        .opacity(showOutcomeSection ? 1 : 0)
        .scaleEffect(showOutcomeSection ? 1 : 0.88)
        .offset(y: showOutcomeSection ? 0 : 12)
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
