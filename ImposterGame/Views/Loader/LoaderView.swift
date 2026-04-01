import SwiftUI

struct LoaderView: View {
    @EnvironmentObject var router: AppRouter
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                Spacer()

                ZStack {
                    // Pulsing background circle
                    Circle()
                        .fill(Color.gradientRedTop.opacity(0.3))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)

                    // App icon placeholder
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.8, green: 0.15, blue: 0.15), Color(red: 0.6, green: 0.1, blue: 0.1)],
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
                        .shadow(color: Color.red.opacity(0.5), radius: 20)
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

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Onboarding is shown on every cold start; paywall / home follow after the flow.
                router.navigate(to: .onboarding)
            }
        }
    }
}
