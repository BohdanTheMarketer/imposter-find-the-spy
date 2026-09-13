import SwiftUI

struct CategoryPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL

    @State private var selection: PaywallSelection = .weekly
    @State private var showRestoreMessage = false
    @State private var restoreResultMessageKey = "paywall.restore_alert_message"
    @State private var showPurchaseIssueMessage = false
    @State private var purchaseIssueMessageKey = "paywall.purchase_pending_message"
    @State private var didClosePaywall = false
    @State private var didLogPaywallViewed = false
    @State private var showDailyPricing = false

    private enum CategoryPaywallLinks {
        static let privacyURL = URL(string: "https://www.verte-bro.com/privacy-policy")
        static let termsURL = URL(string: "https://www.verte-bro.com/terms-and-conditions")
    }

    var body: some View {
        ZStack {
            LinearGradient.appPurpleGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            GeometryReader { proxy in
                let isCompactHeight = proxy.size.height < 780

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        topBar(topPadding: isCompactHeight ? 2 : 10)
                        heroBlock(height: isCompactHeight ? 240 : 285, topPadding: isCompactHeight ? -6 : 4, bottomPadding: isCompactHeight ? 2 : 10)
                        titleBlock(isCompactHeight: isCompactHeight)

                        PaywallBenefitsList()
                            .padding(.top, isCompactHeight ? 6 : 10)

                        Spacer(minLength: isCompactHeight ? 8 : 20)

                        PaywallPlansSection(
                            selection: $selection,
                            subscriptionManager: subscriptionManager,
                            onSelectionChanged: logPlanSelected,
                            showDailyPricing: showDailyPricing
                        )
                        .padding(.top, 12)

                        ctaButton
                            .padding(.top, 16)

                        footerLinks
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
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
            Button(String(localized: "common.ok"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey(restoreResultMessageKey))
        }
        .alert(
            String(localized: "paywall.purchase_issue_alert_title"),
            isPresented: $showPurchaseIssueMessage
        ) {
            Button(String(localized: "common.ok"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey(purchaseIssueMessageKey))
        }
        .onAppear {
            if subscriptionManager.isPremium {
                scheduleClosePaywall(reason: .purchaseSuccess)
                return
            }
            // Only count this as "saw the category paywall" for the post-game fatigue exclusion
            // when it's a genuine in-app trigger (tapped a locked category, pushed on top of
            // [.playerSetup, .categories]). When reached directly from the loader (returning user,
            // path.count <= 1) it's functionally this session's FIRST-touch paywall, not a repeat
            // ask - it must not poison the same-session flag and block the post-game offer.
            if router.path.count > 1 {
                subscriptionManager.hasSeenCategoryPaywallThisSession = true
            }
            showDailyPricing = !subscriptionManager.markPaywallShown()
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsService.logPaywallViewed(context: .category)
            }
            Task {
                await subscriptionManager.refreshStoreProducts(trigger: "category_paywall_appear")
            }
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            guard isPremium else { return }
            scheduleClosePaywall(reason: .purchaseSuccess)
        }
    }

    private func topBar(topPadding: CGFloat) -> some View {
        HStack {
            Spacer()
            Button(action: { closePaywall(reason: .closeButton) }) {
                Image(systemName: "xmark")
                    .font(.antropicSerif(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.top, topPadding)
    }

    private func heroBlock(height: CGFloat, topPadding: CGFloat, bottomPadding: CGFloat) -> some View {
        Group {
            if let heroImage =
                PlayerProfiles.loadBundledImage(named: "CategoryPaywallHeroTop")
                ?? PlayerProfiles.loadBundledImage(named: "PaywallHeroTop") {
                Image(uiImage: heroImage)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.08))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    private func titleBlock(isCompactHeight: Bool) -> some View {
        Text("paywall.headline")
            .font(.antropicSans(size: isCompactHeight ? 38 : 42, weight: .bold))
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .lineSpacing(-2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var isContinueDisabled: Bool {
        subscriptionManager.isPurchasing
            || !subscriptionManager.isPriceLoaded(for: PaywallCopy.subscriptionPlan(for: selection))
    }

    private var ctaButton: some View {
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
            context: .category,
            plan: PaywallCopy.analyticsPlanName(for: selection),
            trialEnabled: PaywallCopy.trialEnabled(
                selection: selection,
                isEligibleForTrial: subscriptionManager.isEligibleForTrial
            )
        )
        Task {
            switch await subscriptionManager.purchaseSubscription(plan: plan, context: .category) {
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
            context: .category,
            plan: PaywallCopy.analyticsPlanName(for: newSelection),
            trialEnabled: PaywallCopy.trialEnabled(
                selection: newSelection,
                isEligibleForTrial: subscriptionManager.isEligibleForTrial
            )
        )
    }

    private func handleRestoreTapped() {
        AnalyticsService.logPaywallRestoreTapped(context: .category)
        Task {
            switch await subscriptionManager.restorePurchases(context: .category) {
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
        HStack(spacing: 26) {
            Button(String(localized: "legal.terms_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .category, linkType: "terms")
                if let url = CategoryPaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button(String(localized: "legal.privacy_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .category, linkType: "privacy")
                if let url = CategoryPaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button(action: handleRestoreTapped) {
                if subscriptionManager.isRestoring {
                    ProgressView()
                        .tint(.white.opacity(0.45))
                } else {
                    Text(String(localized: "paywall.restore"))
                }
            }
            .disabled(subscriptionManager.isRestoring)
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.45))
        .padding(.bottom, 6)
    }

    private func scheduleClosePaywall(reason: AnalyticsService.PaywallCloseReason) {
        Task { @MainActor in
            closePaywall(reason: reason)
        }
    }

    private func closePaywall(reason: AnalyticsService.PaywallCloseReason) {
        guard !didClosePaywall else { return }
        didClosePaywall = true

        AnalyticsService.logPaywallClosed(context: .category, reason: reason)
        // count <= 1 means this paywall itself is the only thing on the stack - reached directly
        // from the loader (returning non-premium user who already completed onboarding earlier),
        // not pushed from CategoriesView on top of [.playerSetup, .categories]. `path.isEmpty`
        // would never be true here since this screen is always on the path while it's shown.
        if router.path.count <= 1 {
            // This IS that user's first-touch paywall pitch this app-lifetime (onboarding itself
            // was skipped for them) - declining it should make them eligible for the post-game
            // offer just like declining OnboardingPaywallView does, not just declining a locked
            // category later (which must NOT set this, or the post-game paywall would fire for
            // ordinary category-paywall bounces too).
            if reason != .purchaseSuccess {
                subscriptionManager.hasDeclinedOnboardingPaywall = true
            }
            router.navigateToPlayerSetup()
            return
        }
        router.pop()
    }
}
