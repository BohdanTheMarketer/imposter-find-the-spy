import SwiftUI

struct ResultView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var phase: ResultPhase = .intrigue
    @State private var intrigueTextIndex = 0
    @State private var showOutcomeSection = false
    @State private var showActionButtons = false
    @State private var headerReveal = false
    @State private var outcomeCardAppeared = false
    @State private var showPostGamePaywall = false
    @State private var showPostGameSurvey = false
    /// Guards against a spurious repeat `.onAppear` (observed after presenting the AdMob
    /// interstitial) re-running the reset + intrigue sequence mid-flow, which briefly flashed the
    /// purple "moment of truth" screen again right before the post-game overlay appeared. Only a
    /// genuinely new `ResultView` instance (next game) should ever run this once more.
    @State private var hasInitializedForThisGame = false
    /// True while the ad-then-overlay decision for this round is in flight. "Play Again" is
    /// disabled during this window - otherwise a fast tap races the async ad await and reaches
    /// `navigateToCategories()` (tearing this view down) before the survey/paywall/rate-us
    /// decision below ever runs, silently losing that round's eligibility the same way the
    /// nav-race bug this sequence used to have did.
    @State private var isResolvingPostRoundOverlay = false

    enum ResultPhase {
        case intrigue
        case reveal
    }

    private let intrigueKeys: [LocalizedStringKey] = [
        "result.intrigue_the",
        "result.intrigue_moment",
        "result.intrigue_of",
        "result.intrigue_truth"
    ]
    /// Keep the "Moment of Truth" sequence intentionally dramatic and slow.
    private let intrigueSpeedMultiplier: Double = 4.0

    private var didPlayersWin: Bool {
        gameSession.gameResult == .playersWin
    }

    private var imposters: [Player] {
        gameSession.players.filter { $0.isImposter }
    }

    private var outcomeTitle: String {
        didPlayersWin
            ? String(localized: "result.title_players_win")
            : String(localized: "result.title_imposter_wins")
    }

    private var outcomeSubtitle: String {
        if didPlayersWin {
            if imposters.count <= 1 {
                return String(localized: "result.subtitle_single_caught")
            }
            if imposters.count == 2 {
                return String(localized: "result.subtitle_two_caught")
            }
            return String(format: NSLocalizedString("result.all_caught_format", comment: ""), imposters.count)
        }
        return String(localized: "result.subtitle_imposter_escaped")
    }

    private var resultBadgeText: String {
        didPlayersWin
            ? String(localized: "result.badge_players_won")
            : String(localized: "result.badge_imposter_won")
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
        .sheet(isPresented: $showPostGamePaywall) {
            PostGamePaywallView()
        }
        .sheet(isPresented: $showPostGameSurvey) {
            PostGameSurveyView()
        }
        .onAppear {
            guard !hasInitializedForThisGame else { return }
            hasInitializedForThisGame = true
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
                // Cohort-relevant user properties, updated on every completed round.
                AnalyticsService.incrementTotalGamesPlayed()
                AnalyticsService.setLastGameResult(result.analyticsValue)
                if let category = gameSession.selectedCategory {
                    AnalyticsService.setLastCategoryPlayed(category.name)
                }
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
                    ForEach(0..<intrigueKeys.count, id: \.self) { index in
                        if index <= intrigueTextIndex {
                            Text(intrigueKeys[index])
                                .font(.evolventa(size: 48, weight: .bold))
                                .foregroundStyle(
                                    index == intrigueKeys.count - 1
                                        ? AnyShapeStyle(Color.appAccent)
                                        : AnyShapeStyle(
                                            LinearGradient(
                                                colors: [.white, .white.opacity(0.88)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(
                                    color: (index == intrigueKeys.count - 1 ? Color.appAccent : Color.gameplayTitle).opacity(0.35),
                                    radius: 18, x: 0, y: 0
                                )
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
                .overlay(GridPatternView().opacity(0.06))

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
                Text("result.screen_title")
                    .font(.evolventa(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 12) {
                    Text(verbatim: outcomeTitle)
                        .font(.evolventa(size: 50, weight: .bold))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .foregroundColor(.appAccentHigh)

                    Text(verbatim: outcomeSubtitle)
                        .font(.evolventa(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    imposterGridSection
                }
                .padding(.top, 12)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                if !gameSession.secretWord.isEmpty {
                    VStack(spacing: 6) {
                        Text("result.secret_word_label")
                            .font(.evolventa(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                            .tracking(1.1)

                        Text(verbatim: gameSession.secretWord)
                            .font(.evolventa(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                Spacer(minLength: 0)

                Group {
                    if showActionButtons {
                        Button(action: {
                            guard !isResolvingPostRoundOverlay else { return }
                            HapticsManager.impact(.medium)
                            AnalyticsService.logResultPlayAgainTapped()
                            gameSession.resetForNewRound()
                            router.navigateToCategories()
                        }) {
                            HStack(spacing: 10) {
                                Text("result.play_again")
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .shadow(color: Color.appAccent.opacity(0.45), radius: 12, x: 0, y: 6)
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
            Text("result.no_imposter")
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
                    .stroke(Color.appAccent, lineWidth: 2.5)
            )
            .shadow(color: Color.appAccent.opacity(0.45), radius: 18, x: 0, y: 0)

            Text(verbatim: imposter.name)
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
        for i in 0..<intrigueKeys.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * wordStep) {
                withAnimation(.easeInOut(duration: 0.2 * intrigueSpeedMultiplier)) {
                    intrigueTextIndex = i
                }
                HapticsManager.impact(i == intrigueKeys.count - 1 ? .medium : .light)
            }
        }

        let lastWordDelay = Double(intrigueKeys.count - 1) * wordStep
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
                // Disabled in the same tick as `showActionButtons = true` above (see
                // `isResolvingPostRoundOverlay`'s own doc comment for why): the "Play Again"
                // button becomes visible at that exact moment, and a fast tap on it replaces the
                // whole nav path (see AppRouter.navigateToCategories), tearing this view down
                // instantly. An earlier version made this same decision synchronously right here
                // with nothing async in between, which left no window for that race - awaiting the
                // interstitial below reopens it, so the button is explicitly held disabled for the
                // duration instead.
                isResolvingPostRoundOverlay = true
                // Decide survey/paywall/rate-us eligibility up front, before the ad. Survey and
                // rate-us both carry one-time side effects (their underlying "games played"
                // counters), so each must be computed exactly once per round - not re-derived
                // after the ad runs.
                let surveyEligible = SurveyService.recordCompletedGameAndCheckEligibility()
                let isPaywallEligible = subscriptionManager.isEligibleForPostGamePaywall
                let rateUsEligible = !surveyEligible && !isPaywallEligible
                    && RateUsService.recordCompletedGameAndCheckEligibility()
                // Survey and the native rate-us prompt are engagement asks, not monetization -
                // stacking either behind a full-screen ad would tank response rates, so both skip
                // the ad entirely this round. The paywall is itself a monetization ask, so it
                // keeps following the ad as before.
                let skipAdForEngagementOverlay = surveyEligible || rateUsEligible

                Task { @MainActor in
                    if !subscriptionManager.isPremium && !skipAdForEngagementOverlay {
                        await AdMobService.shared.showInterstitial()
                        // Small buffer so the ad's own dismissal transition fully finishes before
                        // potentially presenting a sheet on top of it.
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                    resolvePostRoundOverlay(
                        surveyEligible: surveyEligible,
                        isPaywallEligible: isPaywallEligible,
                        rateUsEligible: rateUsEligible
                    )
                    isResolvingPostRoundOverlay = false
                }
            }
        }
    }

    /// Survey beats paywall beats rate-us - never stack two overlays on the same round. Runs once
    /// the ad (if any) has finished. Eligibility for all three was already decided, before the ad,
    /// by the caller - this just acts on it, so it must not re-derive any of it here.
    private func resolvePostRoundOverlay(surveyEligible: Bool, isPaywallEligible: Bool, rateUsEligible: Bool) {
        if surveyEligible {
            // Highest priority for this round: skips both the paywall and the
            // rate-us prompt so the survey doesn't compete with another overlay.
            showPostGameSurvey = true
        } else if isPaywallEligible {
            // Skip the native rate-us prompt this time - it's a system-level overlay that
            // can render on top of our own .sheet if both fire close together, and the
            // paywall is the higher-priority ask for this cohort. RateUsService has its
            // own cooldown/eligibility, so it'll simply get another chance later.
            showPostGamePaywall = true
        } else if rateUsEligible {
            RateUsService.presentReview()
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
