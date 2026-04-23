import SwiftUI

struct OnboardingPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL
    @State private var enableFreeTrial = false
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

                    freeTrialCard
                        .padding(.bottom, 12)

                    pricingCard(
                        plan: .yearly,
                        title: "Yearly",
                        subtitle: subscriptionManager.yearlyPlanSubtitleText,
                        price: subscriptionManager.yearlyPlanWeeklyEquivalentText,
                        selected: selectedPlan == .yearly,
                        dimmed: enableFreeTrial,
                        badgeText: selectedPlan == .yearly ? "Best value" : nil
                    )
                    .padding(.bottom, 10)

                    pricingCard(
                        plan: .weekly,
                        title: "Weekly",
                        subtitle: "Cancel anytime",
                        price: subscriptionManager.weeklyPlanWeeklyPriceText,
                        selected: selectedPlan == .weekly,
                        dimmed: false,
                        badgeText: selectedPlan == .weekly ? "Most popular" : nil
                    )
                    .padding(.bottom, 16)

                    continueButton
                        .padding(.bottom, 10)

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
            closePaywall()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Group {
                if isCloseButtonVisible {
                    Button(action: closePaywall) {
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

    private var freeTrialCard: some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                enableFreeTrial.toggle()
                if enableFreeTrial {
                    selectedPlan = .weekly
                }
            }
        }) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.7), lineWidth: 2)
                            .frame(width: 30, height: 30)
                        if enableFreeTrial {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.antropicSerif(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not sure yet?")
                            .font(.antropicSerif(size: 15.5, weight: .bold))
                            .foregroundColor(.white)
                        Text("Enable free access")
                            .font(.antropicSerif(size: 13.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()
                }

                if enableFreeTrial {
                    Rectangle()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 1)
                        .padding(.leading, 44)

                    Text("0 USD due today \u{2022} 3 days FREE")
                        .font(.antropicSerif(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func pricingCard(
        plan: Plan,
        title: String,
        subtitle: String,
        price: String,
        selected: Bool,
        dimmed: Bool,
        badgeText: String? = nil
    ) -> some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                if plan == .yearly {
                    selectedPlan = .yearly
                    enableFreeTrial = false
                } else {
                    selectedPlan = .weekly
                    enableFreeTrial = true
                }
            }
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
                    .fill(Color.white.opacity(selected ? 0.24 : (dimmed ? 0.14 : 0.19)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(selected ? 1.0 : (dimmed ? 0.2 : 0.65)), lineWidth: selected ? 2.5 : 1.5)
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
            .opacity(dimmed && !selected ? 0.52 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var continueButton: some View {
        Button(action: {
            HapticsManager.impact(.medium)
            let plan: SubscriptionManager.SubscriptionPlan = selectedPlan == .weekly ? .weekly : .yearly
            Task {
                let didPurchase = await subscriptionManager.purchaseSubscription(plan: plan)
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
                if let url = OnboardingPaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button("Privacy") {
                if let url = OnboardingPaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button("Skip") {
                closePaywall()
            }
            Button("Restore") {
                subscriptionManager.restorePurchases()
                showRestoreMessage = true
            }
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.5))
    }

    private func closePaywall() {
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
