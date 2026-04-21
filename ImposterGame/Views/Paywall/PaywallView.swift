import SwiftUI

struct OnboardingPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL
    @State private var enableFreeTrial = false
    @State private var appearAnimation = false
    @State private var showRestoreMessage = false

    private enum OnboardingPaywallLinks {
        static let privacyURL = URL(string: "https://www.verte-bro.com/privacy-policy")
        static let termsURL = URL(string: "https://www.verte-bro.com/terms-and-conditions")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.56, green: 0.26, blue: 1.0), Color(red: 0.43, green: 0.18, blue: 0.87)],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
                .overlay(
                    GridPatternView(lineColor: .white.opacity(0.18))
                        .opacity(0.6)
                )

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 10)
                    .padding(.horizontal, 6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroBlock
                            .padding(.top, 6)
                            .padding(.bottom, 8)

                        Text("Continue to get\nfull access")
                            .font(.antropicSans(size: 42, weight: .heavy))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-2)
                            .minimumScaleFactor(0.68)
                            .padding(.top, 4)
                            .padding(.bottom, 18)

                        freeTrialCard
                            .padding(.bottom, 12)

                        pricingCard(
                            title: "Yearly",
                            subtitle: "Just 49,99 USD/year",
                            price: "0,96 USD/week",
                            highlighted: true,
                            badgeText: "Best value"
                        )
                        .padding(.bottom, 10)

                        pricingCard(
                            title: "Weekly",
                            subtitle: "Cancel anytime",
                            price: "9,99 USD/week",
                            highlighted: false
                        )
                        .padding(.bottom, 16)

                        continueButton
                            .padding(.bottom, 10)

                        footerLinks
                            .padding(.bottom, 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .scaleEffect(appearAnimation ? 1.0 : 0.97)
            .opacity(appearAnimation ? 1.0 : 0.0)
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
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: closePaywall) {
                Image(systemName: "xmark")
                    .font(.antropicSerif(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var heroBlock: some View {
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
        .frame(height: 285)
        .padding(.horizontal, 2)
    }

    private var freeTrialCard: some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                enableFreeTrial.toggle()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.8)
                        .frame(width: 30, height: 30)
                    if enableFreeTrial {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Not sure yet?")
                        .font(.antropicSerif(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Enable free access")
                        .font(.antropicSerif(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.88))
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.4)
            )
        }
        .buttonStyle(.plain)
    }

    private func pricingCard(
        title: String,
        subtitle: String,
        price: String,
        highlighted: Bool,
        badgeText: String? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.antropicSerif(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.antropicSerif(size: 12.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            Text(price)
                .font(.antropicSerif(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(Color.white.opacity(highlighted ? 0.14 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(highlighted ? 0.9 : 0.25), lineWidth: 1.4)
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
                            .fill(Color(red: 0.95, green: 0.2, blue: 0.58))
                    )
                    .offset(x: -8, y: -10)
            }
        }
    }

    private var continueButton: some View {
        Button(action: {
            HapticsManager.impact(.medium)
            let plan: SubscriptionManager.SubscriptionPlan = enableFreeTrial ? .weekly : .yearly
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
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.antropicSerif(size: 19, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 26)
            .frame(height: 66)
            .background(Color(red: 0.09, green: 0.08, blue: 0.15))
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
            Button("Restore") {
                subscriptionManager.restorePurchases()
                showRestoreMessage = true
            }
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.5))
    }

    private func closePaywall() {
        if !router.path.isEmpty {
            router.pop()
        }
    }
}
