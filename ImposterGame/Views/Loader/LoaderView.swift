import SwiftUI

struct LoaderView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    /// Avoid re-running the post-splash navigation when the root loader briefly reappears (e.g. empty `NavigationPath`).
    private static var didScheduleInitialNavigation = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.08)
                )

            VStack {
                Spacer()

                ZStack {
                    // Pulsing background circle
                    Circle()
                        .fill(Color.gameplayButtonPrimary.opacity(0.3))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)

                    // Brand logo
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.black.opacity(0.22))
                        .frame(width: 150, height: 150)
                        .overlay(
                            Image("BrandLogo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 32))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.gameplayButtonPrimary.opacity(0.45), radius: 22)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer()

                // Subtle loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
                    .padding(.bottom, 60)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }

            guard !Self.didScheduleInitialNavigation else { return }
            Self.didScheduleInitialNavigation = true
            // Short beat so the logo can begin its animation; avoid a multi-second artificial wait before onboarding.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if !subscriptionManager.hasCompletedOnboarding {
                    // First launch: onboarding flow includes onboarding paywall.
                    router.navigate(to: .onboarding)
                } else {
                    // Later launches: always show category paywall before player setup.
                    router.navigate(to: .categoryPaywall)
                }
            }
        }
    }
}
