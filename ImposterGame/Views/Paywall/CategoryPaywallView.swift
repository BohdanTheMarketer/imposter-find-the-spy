import SwiftUI

struct CategoryPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isTrialEnabled = false
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

            VStack(spacing: 0) {
                topBar
                heroBlock
                titleBlock

                Spacer(minLength: 20)

                freeAccessCard

                yearlyPlanCard(selected: selectedPlan == .yearly, dimmed: isTrialEnabled)
                    .padding(.top, 12)
                weeklyPlanCard(
                    selected: selectedPlan == .weekly,
                    badgeText: selectedPlan == .weekly ? "Most popular" : nil
                )
                .padding(.top, 10)

                ctaButton
                    .padding(.top, 16)

                footerLinks
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
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
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: { closePaywall() }) {
                Image(systemName: "xmark")
                    .font(.antropicSerif(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.top, 10)
    }

    private var heroBlock: some View {
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
        .frame(height: 285)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var titleBlock: some View {
        Text("Continue to get\nfull access")
            .font(.antropicSans(size: 42, weight: .bold))
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .lineSpacing(-2)
    }

    private var freeAccessCard: some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                isTrialEnabled.toggle()
                if isTrialEnabled {
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
                    if isTrialEnabled {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.antropicSerif(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isTrialEnabled ? "Free access enabled" : "Not sure yet?")
                        .font(.antropicSerif(size: 15.5, weight: .bold))
                        .foregroundColor(.white)
                    Text(isTrialEnabled ? "No commitment, cancel anytime" : "Enable free access")
                        .font(.antropicSerif(size: 13.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()
            }

            if isTrialEnabled {
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

    private func yearlyPlanCard(selected: Bool, dimmed: Bool) -> some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = .yearly
                isTrialEnabled = false
            }
        }) {
            HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Yearly")
                    .font(.antropicSerif(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Just 49,99 USD/year")
                    .font(.antropicSerif(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Text("0,96 USD/week")
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
                if selected {
                    Text("Best value")
                        .font(.antropicSerif(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.95, green: 0.28, blue: 0.63))
                        )
                        .offset(x: -10, y: -10)
                        .zIndex(2)
                }
            }
            .opacity(dimmed && !selected ? 0.52 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func weeklyPlanCard(selected: Bool, badgeText: String?) -> some View {
        Button(action: {
            HapticsManager.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = .weekly
                isTrialEnabled = true
            }
        }) {
            HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly")
                    .font(.antropicSerif(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Cancel anytime")
                    .font(.antropicSerif(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Text("9,99 USD/week")
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
                                .fill(Color(red: 0.95, green: 0.28, blue: 0.63))
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
            subscriptionManager.purchaseSubscription()
            closePaywall()
        }) {
            HStack {
                Text(isTrialEnabled ? "Try it for Free" : "Continue")
                    .font(.antropicSerif(size: 19.5, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.antropicSerif(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 26)
            .frame(height: 64)
            .background(Color(red: 0.13, green: 0.12, blue: 0.2))
            .clipShape(Capsule())
        }
    }

    private var footerLinks: some View {
        HStack(spacing: 26) {
            Button("Terms") {
                if let url = CategoryPaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button("Privacy") {
                if let url = CategoryPaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button("Restore") {
                subscriptionManager.restorePurchases()
                showRestoreMessage = true
            }
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.45))
        .padding(.bottom, 6)
    }

    private func closePaywall() {
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
