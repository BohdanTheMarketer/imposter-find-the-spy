import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var enableFreeTrial = false
    @State private var appearAnimation = false

    var body: some View {
        ZStack {
            // Purple gradient background with grid
            LinearGradient.appPurpleGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)

                // Illustration
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 200, height: 220)

                    VStack {
                        Text("🕵️‍♂️")
                            .font(.system(size: 100))
                        Text("🎉🎊🎈")
                            .font(.system(size: 40))
                    }
                }
                .scaleEffect(appearAnimation ? 1.0 : 0.8)
                .opacity(appearAnimation ? 1.0 : 0)
                .padding(.bottom, 30)

                // Title
                Text("Continue to get\nfull access")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                // Description
                Text("Just 9,99 USD/week. ")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                +
                Text("Full access to 10 themes to match any party! More than 1000 words! Frequent content updates! No extra charge, no commitment. Cancel anytime.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                // Free trial toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not sure yet?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Enable free trial")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Toggle("", isOn: $enableFreeTrial)
                        .labelsHidden()
                        .tint(Color.green)
                }
                .padding(16)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Continue button
                Button(action: {
                    HapticsManager.impact(.medium)
                    subscriptionManager.purchaseSubscription()
                    router.navigate(to: .playerSetup)
                }) {
                    Text("Continue")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Bottom links
                HStack(spacing: 24) {
                    Button("Terms") {}
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    Button("Privacy") {}
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                    Button("Skip") {
                        router.navigate(to: .playerSetup)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    Button("Restore") {
                        subscriptionManager.restorePurchases()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
    }
}
