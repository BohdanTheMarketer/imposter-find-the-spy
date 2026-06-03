import SwiftUI

struct CategoryPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL

    @State private var selectedPlan: Plan = .weekly
    @State private var showRestoreMessage = false
    @State private var didClosePaywall = false

    private enum Plan {
        case yearly
        case weekly
    }

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

                    weeklyPlanCard(
                        selected: selectedPlan == .weekly,
                        badgeText: selectedPlan == .weekly ? String(localized: "paywall.badge_most_popular") : nil
                    )
                    .padding(.top, 12)
                    yearlyPlanCard(selected: selectedPlan == .yearly)
                    .padding(.top, 10)

                    ctaButton
                        .padding(.top, 16)

                    Text(verbatim: selectedPlanTerms)
                        .font(.antropicSerif(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

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

    private func yearlyPlanCard(selected: Bool) -> some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = .yearly
            }
            AnalyticsService.logPaywallPlanSelected(
                context: .category,
                plan: "yearly",
                trialEnabled: selectedPlanHasTrial
            )
        }) {
            PaywallPlanCardBody(
                title: String(localized: "paywall.plan_yearly"),
                subtitle: "\(subscriptionManager.yearlyPlanSubtitleText), \(String(localized: "paywall.auto_renews_suffix"))",
                billedPrice: subscriptionManager.yearlyPlanBilledPriceText,
                trailingNote: subscriptionManager.yearlyPlanWeeklyEquivalentText
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(selected ? 0.24 : 0.19))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(selected ? 1.0 : 0.65), lineWidth: selected ? 2.5 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Text("paywall.badge_best_value")
                        .font(.antropicSerif(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.appAccent)
                        )
                        .offset(x: -10, y: -10)
                        .zIndex(2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func weeklyPlanCard(selected: Bool, badgeText: String?) -> some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = .weekly
            }
            AnalyticsService.logPaywallPlanSelected(
                context: .category,
                plan: "weekly",
                trialEnabled: selectedPlanHasTrial
            )
        }) {
            PaywallPlanCardBody(
                title: String(localized: "paywall.plan_weekly"),
                subtitle: weeklyTrialSubtitle,
                billedPrice: subscriptionManager.weeklyPlanWeeklyPriceText,
                trailingNote: String(localized: "paywall.cancel_anytime"),
                subtitleLineLimit: 2
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(selected ? 0.22 : 0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(selected ? 0.95 : 0.45), lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if let badgeText {
                    Text(verbatim: badgeText)
                        .font(.antropicSerif(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.appAccent)
                        )
                        .offset(x: -10, y: -10)
                        .zIndex(2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var ctaButton: some View {
        Group {
            if PaywallCopy.usesDualLineCTA(selectedPlanIsWeekly: selectedPlan == .weekly) {
                PaywallDualLineCTAButton(
                    billedLine: PaywallCopy.ctaBilledLine(
                        subscriptionManager: subscriptionManager,
                        plan: .weekly
                    ),
                    subordinateLineKey: PaywallCopy.ctaSubordinateLineKey(showsTrialPitch: selectedPlanHasTrial),
                    action: handleContinueTapped
                )
            } else {
                PaywallSingleLineCTAButton(
                    titleKey: "paywall.continue",
                    action: handleContinueTapped
                )
            }
        }
    }

    private func handleContinueTapped() {
        if subscriptionManager.isPremium {
            closePaywall(reason: .purchaseSuccess)
            return
        }
        HapticsManager.impact(.medium)
        let plan = selectedSubscriptionPlan
        AnalyticsService.logPaywallContinueTapped(
            context: .category,
            plan: selectedPlan == .weekly ? "weekly" : "yearly",
            trialEnabled: selectedPlanHasTrial
        )
        Task {
            let didPurchase = await subscriptionManager.purchaseSubscription(plan: plan, context: .category)
            if didPurchase {
                scheduleClosePaywall(reason: .purchaseSuccess)
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

    private var weeklyTrialSubtitle: String {
        let price = subscriptionManager.weeklyPlanWeeklyPriceText
        if selectedPlanHasTrial {
            return LocalizationService.shared.localizedFormat(
                "paywall.weekly_trial_subtitle",
                price
            )
        }
        return "\(price), \(LocalizationService.shared.localized("paywall.auto_renews_suffix"))"
    }

    private var selectedSubscriptionPlan: SubscriptionManager.SubscriptionPlan {
        selectedPlan == .weekly ? .weekly : .yearly
    }

    private var selectedPlanHasTrial: Bool {
        selectedPlan == .weekly && subscriptionManager.isEligibleForTrial
    }

    private var selectedPlanTerms: String {
        subscriptionManager.displayTerms(for: selectedSubscriptionPlan)
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
