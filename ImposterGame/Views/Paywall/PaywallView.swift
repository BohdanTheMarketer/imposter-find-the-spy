import SwiftUI

struct OnboardingPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL
    @State private var selectedPlan: Plan = .yearly
    @State private var appearAnimation = false
    @State private var showRestoreMessage = false
    @State private var isCloseButtonVisible = false
    @State private var closeButtonRevealTask: Task<Void, Never>?

    private enum Plan {
        case yearly
        case weekly
    }

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

                VStack(spacing: 0) {
                    topBar
                        .padding(.top, isCompactHeight ? 2 : 10)
                        .padding(.horizontal, 6)

                    heroBlock(height: isCompactHeight ? 240 : 285)
                        .padding(.top, isCompactHeight ? -6 : 6)
                        .padding(.bottom, isCompactHeight ? 2 : 8)

                    Text("Continue to get\nfull access")
                        .font(.antropicSans(size: isCompactHeight ? 38 : 42, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-2)
                        .minimumScaleFactor(0.68)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, isCompactHeight ? 0 : 4)

                    Spacer(minLength: isCompactHeight ? 8 : 20)

                    pricingCard(
                        plan: .yearly,
                        title: "Yearly",
                        subtitle: "\(subscriptionManager.yearlyPlanSubtitleText), auto-renews",
                        price: subscriptionManager.yearlyPlanWeeklyEquivalentText,
                        selected: selectedPlan == .yearly,
                        badgeText: selectedPlan == .yearly ? "Best value" : nil
                    )
                    .padding(.bottom, 10)

                    pricingCard(
                        plan: .weekly,
                        title: "Weekly",
                        subtitle: "\(subscriptionManager.weeklyPlanWeeklyPriceText), auto-renews",
                        price: subscriptionManager.weeklyPlanWeeklyPriceText,
                        selected: selectedPlan == .weekly,
                        badgeText: selectedPlan == .weekly ? "Most popular" : nil
                    )
                    .padding(.bottom, 16)

                    continueButton
                        .padding(.bottom, 6)

                    Text(selectedPlanTerms)
                        .font(.antropicSerif(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)

                    footerLinks
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
                .scaleEffect(appearAnimation ? 1.0 : 0.97)
                .opacity(appearAnimation ? 1.0 : 0.0)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .alert("Restore Purchases", isPresented: $showRestoreMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("If you have an active subscription, it will be restored shortly.")
        }
        .onAppear {
            AnalyticsService.logEvent("paywall_show", parameters: ["context": "onboarding"])
            AnalyticsService.logPaywallViewed(context: .onboarding)
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
            closePaywall(reason: .purchaseSuccess)
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
        .padding(.horizontal, 2)
    }

    private func pricingCard(
        plan: Plan,
        title: String,
        subtitle: String,
        price: String,
        selected: Bool,
        badgeText: String? = nil
    ) -> some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = plan
            }
            AnalyticsService.logPaywallPlanSelected(
                context: .onboarding,
                plan: selectedPlan == .weekly ? "weekly" : "yearly",
                trialEnabled: selectedPlanHasTrial
            )
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.antropicSerif(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.antropicSerif(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Text(price)
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

    private var continueButton: some View {
        Button(action: {
            HapticsManager.impact(.medium)
            let plan: SubscriptionManager.SubscriptionPlan = selectedPlan == .weekly ? .weekly : .yearly
            AnalyticsService.logPaywallContinueTapped(
                context: .onboarding,
                plan: selectedPlan == .weekly ? "weekly" : "yearly",
                trialEnabled: selectedPlanHasTrial
            )
            Task {
                let didPurchase = await subscriptionManager.purchaseSubscription(plan: plan, context: .onboarding)
                if didPurchase {
                    router.navigate(to: .playerSetup)
                }
            }
        }) {
            HStack {
                Text("Continue")
                    .font(.antropicSerif(size: 21, weight: .heavy))
                    .foregroundColor(.appTextOnAccent)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.antropicSerif(size: 19, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
            }
            .padding(.horizontal, 26)
            .frame(height: 66)
            .background(Color.appAccent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var footerLinks: some View {
        HStack(spacing: 30) {
            Button("Terms") {
                AnalyticsService.logPaywallLinkTapped(context: .onboarding, linkType: "terms")
                if let url = OnboardingPaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button("Privacy") {
                AnalyticsService.logPaywallLinkTapped(context: .onboarding, linkType: "privacy")
                if let url = OnboardingPaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button("Skip") {
                closePaywall(reason: .skip)
            }
            Button("Restore") {
                AnalyticsService.logPaywallRestoreTapped(context: .onboarding)
                subscriptionManager.restorePurchases(context: .onboarding)
                showRestoreMessage = true
            }
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.5))
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
        AnalyticsService.logPaywallClosed(context: .onboarding, reason: reason)
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
