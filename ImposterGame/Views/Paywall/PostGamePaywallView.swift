import SwiftUI

/// Full-screen "super special offer" shown once, right after a user's first completed game -
/// only to users who saw and declined the onboarding paywall and haven't purchased. The offer
/// itself (price, discount, duration) is baked into the `SuperOfferHero` creative, so this view
/// only adds the interactive chrome on top: a CTA button and the legal/restore footer required
/// alongside any purchase button. Presented as a `.fullScreenCover`, not a sheet, so the creative
/// gets full visual weight; a top-right close button (revealed after a short delay, same pattern
/// as `OnboardingPaywallView`) and the footer's "Not now" are the ways out.
struct PostGamePaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var didFinish = false
    @State private var didLogPaywallViewed = false
    @State private var showRestoreMessage = false
    @State private var restoreResultMessageKey = "paywall.restore_alert_message"
    @State private var showPurchaseIssueMessage = false
    @State private var purchaseIssueMessageKey = "paywall.purchase_pending_message"
    @State private var appearAnimation = false
    @State private var playBonusConfetti = false
    @State private var isCloseButtonVisible = false
    @State private var closeButtonRevealTask: Task<Void, Never>?

    private enum PostGamePaywallLinks {
        static let privacyURL = URL(string: "https://www.verte-bro.com/privacy-policy")
        static let termsURL = URL(string: "https://www.verte-bro.com/terms-and-conditions")
    }

    private var isContinueDisabled: Bool {
        subscriptionManager.isPurchasing || !subscriptionManager.isPriceLoaded(for: .weeklySpecialOffer)
    }

    var body: some View {
        ZStack {
            heroBackground

            LinearGradient(
                colors: [.clear, .clear, Color.black.opacity(0.55), Color.black.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if playBonusConfetti {
                SuperOfferConfettiBurst()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack {
                HStack {
                    Spacer()
                    if isCloseButtonVisible {
                        closeButton
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                bottomContent
                    .opacity(appearAnimation ? 1.0 : 0.0)
                    .offset(y: appearAnimation ? 0 : 18)
            }
        }
        .alert(
            String(localized: "paywall.restore_alert_title"),
            isPresented: $showRestoreMessage
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(restoreResultMessageKey))
        }
        .alert(
            String(localized: "paywall.purchase_issue_alert_title"),
            isPresented: $showPurchaseIssueMessage
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(purchaseIssueMessageKey))
        }
        .onAppear {
            subscriptionManager.markPostGamePaywallShown()
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsService.logPaywallViewed(context: .postGame)
            }
            Task {
                await subscriptionManager.refreshStoreProducts(trigger: "postgame_paywall_appear")
            }
            withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) {
                appearAnimation = true
            }
            playBonusConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                playBonusConfetti = false
            }
            scheduleCloseButtonReveal()
        }
        .onDisappear {
            closeButtonRevealTask?.cancel()
            guard !didFinish else { return }
            didFinish = true
            AnalyticsService.logPaywallClosed(context: .postGame, reason: .skip)
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            guard isPremium else { return }
            finish(reason: .purchaseSuccess)
        }
    }

    // MARK: - Close button (top-right, revealed after a delay - same pattern as the onboarding paywall)

    private var closeButton: some View {
        Button(action: { finish(reason: .closeButton) }) {
            Image(systemName: "xmark")
                .font(.antropicSerif(size: 15, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.black.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }

    private func scheduleCloseButtonReveal() {
        closeButtonRevealTask?.cancel()
        closeButtonRevealTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCloseButtonVisible = true
                }
            }
        }
    }

    // MARK: - Background

    private var heroBackground: some View {
        GeometryReader { proxy in
            Group {
                if let hero = PlayerProfiles.loadBundledImage(named: "SuperOfferHero") {
                    Image(uiImage: hero)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient.appPurpleGradient
                }
            }
            // Top-aligned so the offer callout baked into the top of the creative never gets
            // cropped - any overflow is trimmed from the bottom instead.
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom content

    private var bottomContent: some View {
        VStack(spacing: 14) {
            SuperOfferCTAButton(
                titleKey: "paywall.superoffer.cta",
                action: handleContinueTapped,
                isLoading: isContinueDisabled
            )

            footerLinks

            Text(verbatim: subscriptionManager.displayTerms(for: .weeklySpecialOffer))
                .font(.antropicSerif(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func handleContinueTapped() {
        guard !isContinueDisabled else { return }
        HapticsManager.impact(.medium)
        AnalyticsService.logPaywallContinueTapped(
            context: .postGame,
            plan: SubscriptionManager.SubscriptionPlan.weeklySpecialOffer.analyticsValue,
            trialEnabled: subscriptionManager.isEligibleForTrial
        )
        Task {
            switch await subscriptionManager.purchaseSubscription(plan: .weeklySpecialOffer, context: .postGame) {
            case .success:
                finish(reason: .purchaseSuccess)
            case .userCancelled:
                break
            case .pending:
                purchaseIssueMessageKey = "paywall.purchase_pending_message"
                showPurchaseIssueMessage = true
            case .failed:
                purchaseIssueMessageKey = "paywall.purchase_error_message"
                showPurchaseIssueMessage = true
            }
        }
    }

    private func handleRestoreTapped() {
        AnalyticsService.logPaywallRestoreTapped(context: .postGame)
        Task {
            switch await subscriptionManager.restorePurchases(context: .postGame) {
            case .restored:
                break
            case .noPurchasesFound:
                restoreResultMessageKey = "paywall.restore_alert_message"
                showRestoreMessage = true
            case .failed:
                restoreResultMessageKey = "paywall.restore_error_message"
                showRestoreMessage = true
            }
        }
    }

    private func finish(reason: AnalyticsService.PaywallCloseReason) {
        guard !didFinish else { return }
        didFinish = true
        AnalyticsService.logPaywallClosed(context: .postGame, reason: reason)
        dismiss()
    }

    private var footerLinks: some View {
        HStack(spacing: 26) {
            Button(String(localized: "legal.terms_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .postGame, linkType: "terms")
                if let url = PostGamePaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button(String(localized: "legal.privacy_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .postGame, linkType: "privacy")
                if let url = PostGamePaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button(action: handleRestoreTapped) {
                if subscriptionManager.isRestoring {
                    ProgressView()
                        .tint(.white.opacity(0.5))
                } else {
                    Text(String(localized: "paywall.restore"))
                }
            }
            .disabled(subscriptionManager.isRestoring)
            Button(String(localized: "paywall.postgame.not_now")) {
                finish(reason: .skip)
            }
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.5))
    }
}

// MARK: - CTA button

/// Stand-in for the shared `PaywallSingleLineCTAButton` on this screen only - same dark
/// design-system color as every other paywall CTA, plus a continuous gentle "breathing" pulse and
/// an occasional slow, smooth sway (paired with a soft haptic tick) to keep drawing the eye back
/// to it without being jarring about it.
private struct SuperOfferCTAButton: View {
    let titleKey: String
    let action: () -> Void
    var isLoading = false

    @State private var pulse = false
    @State private var wobbleAngle: Double = 0
    @State private var nudgeTask: Task<Void, Never>?

    var body: some View {
        Button(action: action) {
            HStack {
                Text(LocalizedStringKey(titleKey))
                    .font(.antropicSerif(size: 19, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.antropicSerif(size: 19, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 22)
            .frame(height: 60)
            .background(Color.stitchDeepOnyx)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
            .opacity(isLoading ? 0.7 : 1.0)
            .scaleEffect(pulse ? 1.03 : 1.0)
            .rotationEffect(.degrees(wobbleAngle))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            scheduleNudges()
        }
        .onDisappear {
            nudgeTask?.cancel()
        }
    }

    private func scheduleNudges() {
        nudgeTask?.cancel()
        nudgeTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                HapticsManager.impact(.soft)
                await sway()
            }
        }
    }

    /// A slow, smooth two-beat tilt rather than a sharp shake - calmer, easier on the eye.
    private func sway() async {
        withAnimation(.easeInOut(duration: 0.4)) {
            wobbleAngle = 2.0
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation(.easeInOut(duration: 0.4)) {
            wobbleAngle = -2.0
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation(.easeInOut(duration: 0.35)) {
            wobbleAngle = 0
        }
    }
}

// MARK: - Bonus animation

/// One-shot celebratory confetti burst played for a few seconds when the offer appears - the
/// "you've unlocked a gift" moment, distinct from `ResultView`'s falling confetti which loops.
private struct SuperOfferConfettiBurst: View {
    private struct Piece: Identifiable {
        let id: Int
        let x: Double
        let delay: Double
        let duration: Double
        let size: CGFloat
        let drift: CGFloat
    }

    private let palette: [Color] = [.revealGreen, .white, Color(red: 1.0, green: 0.82, blue: 0.35), .revealOrange]

    private let pieces: [Piece] = SuperOfferConfettiBurst.makePieces()

    private static func makePieces() -> [Piece] {
        var pieces: [Piece] = []
        for index in 0..<28 {
            let x: Double = Double((index * 31) % 100) / 100.0
            let delay: Double = Double((index * 5) % 14) / 10.0
            let duration: Double = 2.6 + Double((index * 9) % 14) / 10.0
            let size: CGFloat = CGFloat(6 + (index % 6))
            let drift: CGFloat = CGFloat((index % 5) * 14) - 28
            pieces.append(Piece(id: index, x: x, delay: delay, duration: duration, size: size, drift: drift))
        }
        return pieces
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(palette[piece.id % palette.count])
                        .frame(
                            width: piece.id.isMultiple(of: 3) ? piece.size * 0.5 : piece.size,
                            height: piece.size
                        )
                        .position(x: geo.size.width * piece.x, y: -12)
                        .modifier(
                            FallingConfettiBurstAnimation(
                                delay: piece.delay,
                                duration: piece.duration,
                                dropDistance: geo.size.height * 0.6,
                                drift: piece.drift
                            )
                        )
                }
            }
        }
    }
}

private struct FallingConfettiBurstAnimation: ViewModifier {
    let delay: Double
    let duration: Double
    let dropDistance: CGFloat
    let drift: CGFloat
    @State private var animate = false

    func body(content: Content) -> some View {
        content
            .opacity(animate ? 0 : 0.9)
            .rotationEffect(.degrees(animate ? 240 : 0))
            .offset(x: animate ? drift : 0, y: animate ? dropDistance : -10)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    animate = true
                }
            }
    }
}
