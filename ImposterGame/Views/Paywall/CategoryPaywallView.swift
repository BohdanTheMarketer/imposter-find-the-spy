import SwiftUI

struct CategoryPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var isTrialEnabled = false

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

                if isTrialEnabled {
                    weeklyPlanCard(selected: true, badgeText: "Most popular")
                        .padding(.top, 12)
                    yearlyPlanCard(dimmed: true)
                        .padding(.top, 10)
                } else {
                    yearlyPlanCard(dimmed: false)
                        .padding(.top, 12)
                    weeklyPlanCard(selected: false, badgeText: "Best value")
                        .padding(.top, 10)
                }

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
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: { closePaywall() }) {
                Image(systemName: "xmark")
                    .font(.evolventa(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.top, 10)
    }

    private var heroBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.42, blue: 0.08), Color(red: 0.98, green: 0.23, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 210, height: 240)

            VStack(spacing: 12) {
                Text("🕵️‍♂️")
                    .font(.evolventa(size: 92))
                Text("🎉🎈✨")
                    .font(.evolventa(size: 28))
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private var titleBlock: some View {
        Text("Continue to get\nfull access")
            .font(.evolventa(size: 50, weight: .heavy))
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .lineSpacing(-4)
    }

    private var freeAccessCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: {
                    HapticsManager.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isTrialEnabled.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.7), lineWidth: 2)
                            .frame(width: 30, height: 30)
                        if isTrialEnabled {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.evolventa(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isTrialEnabled ? "Free access enabled" : "Not sure yet?")
                        .font(.evolventa(size: 15.5, weight: .bold))
                        .foregroundColor(.white)
                    Text(isTrialEnabled ? "No commitment, cancel anytime" : "Enable free access")
                        .font(.evolventa(size: 13.5, weight: .medium))
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
                    .font(.evolventa(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
        )
    }

    private func yearlyPlanCard(dimmed: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Yearly")
                    .font(.evolventa(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Just 49,99 USD/year")
                    .font(.evolventa(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Text("0,96 USD/week")
                .font(.evolventa(size: 16.5, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(dimmed ? 0.08 : 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(dimmed ? 0.2 : 0.65), lineWidth: 1.5)
        )
        .opacity(dimmed ? 0.52 : 1.0)
    }

    private func weeklyPlanCard(selected: Bool, badgeText: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly")
                    .font(.evolventa(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Cancel anytime")
                    .font(.evolventa(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
            Text("9,99 USD/week")
                .font(.evolventa(size: 16.5, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(selected ? 0.18 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            Text(badgeText)
                .font(.evolventa(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.28, blue: 0.63))
                )
                .offset(x: -10, y: -10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(selected ? 0.95 : 0.45), lineWidth: 1.5)
        )
    }

    private var ctaButton: some View {
        Button(action: {
            HapticsManager.impact(.medium)
            subscriptionManager.purchaseSubscription()
            closePaywall()
        }) {
            HStack {
                Text(isTrialEnabled ? "Try it for Free" : "Continue")
                    .font(.evolventa(size: 19.5, weight: .heavy))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.evolventa(size: 18, weight: .bold))
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
            Button("Terms") {}
            Button("Privacy") {}
            Button("Restore") {
                subscriptionManager.restorePurchases()
            }
        }
        .font(.evolventa(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.45))
        .padding(.bottom, 6)
    }

    private func closePaywall() {
        dismiss()
        if !router.path.isEmpty {
            router.pop()
        }
    }
}
