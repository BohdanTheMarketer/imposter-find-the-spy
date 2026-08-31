import SwiftUI

struct OnboardingPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL
    @State private var selection: PaywallSelection = .weekly
    @State private var appearAnimation = false
    @State private var showRestoreMessage = false
    @State private var restoreResultMessageKey = "paywall.restore_alert_message"
    @State private var showPurchaseIssueMessage = false
    @State private var purchaseIssueMessageKey = "paywall.purchase_pending_message"
    @State private var isCloseButtonVisible = false
    @State private var closeButtonRevealTask: Task<Void, Never>?
    @State private var didClosePaywall = false
    @State private var didLogPaywallViewed = false

    private enum OnboardingPaywallLinks {
        static let privacyURL = URL(string: "https://www.verte-bro.com/privacy-policy")
        static let termsURL = URL(string: "https://www.verte-bro.com/terms-and-conditions")
    }

    var body: some View {
        ZStack {
            LinearGradient.appPurpleGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView(lineColor: .white.opacity(0.18))
                        .opacity(0.6)
                )

            GeometryReader { proxy in
                let isCompactHeight = proxy.size.height < 780

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        topBar
                            .padding(.top, isCompactHeight ? 2 : 10)
                            .padding(.horizontal, 6)

                        heroBlock(height: isCompactHeight ? 240 : 285)
                            .padding(.top, isCompactHeight ? -6 : 6)
                            .padding(.bottom, isCompactHeight ? 2 : 8)

                        Text("paywall.headline")
                            .font(.antropicSans(size: isCompactHeight ? 38 : 42, weight: .heavy))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-2)
                            .minimumScaleFactor(0.68)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, isCompactHeight ? 0 : 4)

                        PaywallBenefitsList()
                            .padding(.top, isCompactHeight ? 6 : 10)

                        Spacer(minLength: isCompactHeight ? 8 : 20)

                        PaywallPlansSection(
                            selection: $selection,
                            subscriptionManager: subscriptionManager,
                            onSelectionChanged: logPlanSelected
                        )

                        continueButton
                            .padding(.top, 12)
                            .padding(.bottom, 6)

                        footerLinks
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 20)
                    .scaleEffect(appearAnimation ? 1.0 : 0.97)
                    .opacity(appearAnimation ? 1.0 : 0.0)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
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
            if subscriptionManager.isPremium {
                scheduleClosePaywall(reason: .purchaseSuccess)
                return
            }
            // Onboarding paywall always shows full price, never the "$X/day" breakdown - it's
            // the very first paywall a user ever sees, unlike category/post-game which may
            // reasonably switch to daily framing on a repeat view.
            subscriptionManager.markPaywallShown()
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsService.logPaywallViewed(context: .onboarding)
            }
            Task {
                await subscriptionManager.refreshStoreProducts(trigger: "onboarding_paywall_appear")
            }
            isCloseButtonVisible = false
            scheduleCloseButtonReveal()
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
        .onDisappear {
            closeButtonRevealTask?.cancel()
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            guard isPremium else { return }
            scheduleClosePaywall(reason: .purchaseSuccess)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Group {
                if isCloseButtonVisible {
                    Button(action: {
                        closePaywall(reason: .closeButton)
                    }) {
                        Image(systemName: "xmark")
                            .font(.antropicSerif(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                }
            }
        }
    }

    private func heroBlock(height: CGFloat) -> some View {
        Group {
            if let heroImage = PlayerProfiles.loadBundledImage(named: "PaywallHeroTop") {
                Image(uiImage: heroImage.removingBlackBackgroundFromEdges(cacheKey: "PaywallHeroTop") ?? heroImage)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.08))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, 2)
    }

    private var isContinueDisabled: Bool {
        subscriptionManager.isPurchasing
            || !subscriptionManager.isPriceLoaded(for: PaywallCopy.subscriptionPlan(for: selection))
    }

    private var continueButton: some View {
        PaywallSingleLineCTAButton(
            titleKey: PaywallCopy.ctaTitleKey(
                selection: selection,
                isEligibleForTrial: subscriptionManager.isEligibleForTrial
            ),
            action: handleContinueTapped,
            isLoading: isContinueDisabled
        )
    }

    private func handleContinueTapped() {
        if subscriptionManager.isPremium {
            closePaywall(reason: .purchaseSuccess)
            return
        }
        guard !isContinueDisabled else { return }
        HapticsManager.impact(.medium)
        let plan = PaywallCopy.subscriptionPlan(for: selection)
        AnalyticsService.logPaywallContinueTapped(
            context: .onboarding,
            plan: PaywallCopy.analyticsPlanName(for: selection),
            trialEnabled: PaywallCopy.trialEnabled(
                selection: selection,
                isEligibleForTrial: subscriptionManager.isEligibleForTrial
            )
        )
        Task {
            switch await subscriptionManager.purchaseSubscription(plan: plan, context: .onboarding) {
            case .success:
                scheduleClosePaywall(reason: .purchaseSuccess)
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

    private func logPlanSelected(_ newSelection: PaywallSelection) {
        AnalyticsService.logPaywallPlanSelected(
            context: .onboarding,
            plan: PaywallCopy.analyticsPlanName(for: newSelection),
            trialEnabled: PaywallCopy.trialEnabled(
                selection: newSelection,
                isEligibleForTrial: subscriptionManager.isEligibleForTrial
            )
        )
    }

    private func handleRestoreTapped() {
        AnalyticsService.logPaywallRestoreTapped(context: .onboarding)
        Task {
            switch await subscriptionManager.restorePurchases(context: .onboarding) {
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

    private var footerLinks: some View {
        HStack(spacing: 30) {
            Button(String(localized: "legal.terms_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .onboarding, linkType: "terms")
                if let url = OnboardingPaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button(String(localized: "legal.privacy_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .onboarding, linkType: "privacy")
                if let url = OnboardingPaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button(String(localized: "paywall.skip")) {
                closePaywall(reason: .skip)
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
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.5))
    }

    private func scheduleClosePaywall(reason: AnalyticsService.PaywallCloseReason) {
        Task { @MainActor in
            closePaywall(reason: reason)
        }
    }

    private func closePaywall(reason: AnalyticsService.PaywallCloseReason) {
        guard !didClosePaywall else { return }
        didClosePaywall = true

        if reason != .purchaseSuccess {
            subscriptionManager.hasDeclinedOnboardingPaywall = true
        }

        AnalyticsService.logPaywallClosed(context: .onboarding, reason: reason)
        // Paywall now shows before player setup - players haven't been entered yet, so route
        // there next instead of skipping ahead to categories.
        router.navigateToPlayerSetup()
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
}
