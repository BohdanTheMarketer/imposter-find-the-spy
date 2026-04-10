import SwiftUI

struct LoaderView: View {
    @EnvironmentObject var router: AppRouter
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

                    // App icon placeholder
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [Color.gameplayButtonPrimary, Color(red: 0.70, green: 0.03, blue: 0.43)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 150, height: 150)
                        .overlay(
                            VStack(spacing: 4) {
                                Text("🕵️")
                                    .font(.evolventa(size: 60))
                                Text("❓")
                                    .font(.evolventa(size: 30))
                                    .offset(x: 30, y: -20)
                            }
                        )
                        .shadow(color: Color.gameplayButtonPrimary.opacity(0.5), radius: 20)
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
                // Onboarding is shown on every cold start; paywall / home follow after the flow.
                router.navigate(to: .onboarding)
            }
        }
    }
}
