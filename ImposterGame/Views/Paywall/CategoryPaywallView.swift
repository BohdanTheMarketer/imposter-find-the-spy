import SwiftUI

struct CategoryPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPlan: Plan = .yearly
    @State private var showRestoreMessage = false

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

                    yearlyPlanCard(selected: selectedPlan == .yearly)
                        .padding(.top, 12)
                    weeklyPlanCard(
                        selected: selectedPlan == .weekly,
                        badgeText: selectedPlan == .weekly ? "Most popular" : nil
                    )
                    .padding(.top, 10)

                    ctaButton
                        .padding(.top, 16)

                    Text(selectedPlanTerms)
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
        .alert("Restore Purchases", isPresented: $showRestoreMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("If you have an active subscription, it will be restored shortly.")
        }
        .onAppear {
            AnalyticsService.logEvent("paywall_show", parameters: ["context": "category"])
            AnalyticsService.logPaywallViewed(context: .category)
            Task {
                await subscriptionManager.refreshStoreProducts(trigger: "category_paywall_appear")
            }
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            guard isPremium else { return }
            closePaywall(reason: .purchaseSuccess)
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
        Text("Continue to get\nfull access")
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
            HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Yearly")
                    .font(.antropicSerif(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("\(subscriptionManager.yearlyPlanSubtitleText), auto-renews")
                    .font(.antropicSerif(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Text(subscriptionManager.yearlyPlanWeeklyEquivalentText)
                .font(.antropicSerif(size: 16.5, weight: .bold))
                .foregroundColor(.white)
            }
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
                    Text("Best value")
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
            HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly")
                    .font(.antropicSerif(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("\(subscriptionManager.weeklyPlanWeeklyPriceText), auto-renews")
                    .font(.antropicSerif(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Text(subscriptionManager.weeklyPlanWeeklyPriceText)
                .font(.antropicSerif(size: 16.5, weight: .bold))
                .foregroundColor(.white)
            }
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
                    Text(badgeText)
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
        Button(action: {
            HapticsManager.impact(.medium)
            let plan: SubscriptionManager.SubscriptionPlan = selectedPlan == .weekly ? .weekly : .yearly
            AnalyticsService.logPaywallContinueTapped(
                context: .category,
                plan: selectedPlan == .weekly ? "weekly" : "yearly",
                trialEnabled: selectedPlanHasTrial
            )
            Task {
                let didPurchase = await subscriptionManager.purchaseSubscription(plan: plan, context: .category)
                if didPurchase {
                    closePaywall(reason: .purchaseSuccess)
                }
            }
        }) {
            HStack {
                Text("Continue")
                    .font(.antropicSerif(size: 19.5, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.antropicSerif(size: 18, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
            }
            .padding(.horizontal, 26)
            .frame(height: 64)
            .background(Color.appAccent)
            .clipShape(Capsule())
        }
    }

    private var footerLinks: some View {
        HStack(spacing: 26) {
            Button("Terms") {
                AnalyticsService.logPaywallLinkTapped(context: .category, linkType: "terms")
                if let url = CategoryPaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button("Privacy") {
                AnalyticsService.logPaywallLinkTapped(context: .category, linkType: "privacy")
                if let url = CategoryPaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button("Restore") {
                AnalyticsService.logPaywallRestoreTapped(context: .category)
                subscriptionManager.restorePurchases(context: .category)
                showRestoreMessage = true
            }
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.45))
        .padding(.bottom, 6)
    }

    private var selectedSubscriptionPlan: SubscriptionManager.SubscriptionPlan {
        selectedPlan == .weekly ? .weekly : .yearly
    }

    private var selectedPlanHasTrial: Bool {
        subscriptionManager.hasIntroOffer(for: selectedSubscriptionPlan)
    }

    private var selectedPlanTerms: String {
        subscriptionManager.displayTerms(for: selectedSubscriptionPlan)
    }

    private func closePaywall(reason: AnalyticsService.PaywallCloseReason) {
        AnalyticsService.logPaywallClosed(context: .category, reason: reason)
        if router.path.count <= 1 {
            router.navigate(to: .playerSetup)
            return
        }
        dismiss()
        if !router.path.isEmpty {
            router.pop()
        }
    }
}
