import SwiftUI

struct CategoryPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL

    @State private var selection: PaywallSelection = .yearly
    @State private var showRestoreMessage = false
    @State private var didClosePaywall = false

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

                VStack(spacing: 0) {
                    topBar(topPadding: isCompactHeight ? 2 : 10)
                    heroBlock(height: isCompactHeight ? 240 : 285, topPadding: isCompactHeight ? -6 : 4, bottomPadding: isCompactHeight ? 2 : 10)
                    titleBlock(isCompactHeight: isCompactHeight)

                    Spacer(minLength: isCompactHeight ? 8 : 20)

                    PaywallPlansSection(
                        selection: $selection,
                        subscriptionManager: subscriptionManager,
                        onSelectionChanged: logPlanSelected
                    )
                    .padding(.top, 12)

                    ctaButton
                        .padding(.top, 16)

                    footerLinks
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
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
            Text("paywall.restore_alert_message")
        }
        .onAppear {
            if subscriptionManager.isPremium {
                scheduleClosePaywall(reason: .purchaseSuccess)
                return
            }
            AnalyticsService.logEvent("paywall_show", parameters: ["context": "category"])
            AnalyticsService.logPaywallViewed(context: .category)
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

    private var ctaButton: some View {
        PaywallSingleLineCTAButton(
            titleKey: PaywallCopy.ctaTitleKey(
                selection: selection,
                isEligibleForTrial: subscriptionManager.isEligibleForTrial
            ),
            action: handleContinueTapped
        )
    }

    private func handleContinueTapped() {
        if subscriptionManager.isPremium {
            closePaywall(reason: .purchaseSuccess)
            return
        }
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
            let didPurchase = await subscriptionManager.purchaseSubscription(plan: plan, context: .category)
            if didPurchase {
                scheduleClosePaywall(reason: .purchaseSuccess)
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
            Button(String(localized: "paywall.restore")) {
                AnalyticsService.logPaywallRestoreTapped(context: .category)
                subscriptionManager.restorePurchases(context: .category)
                showRestoreMessage = true
            }
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
        if router.path.isEmpty {
            router.navigateToPlayerSetup()
            return
        }
        router.pop()
    }
}
