import SwiftUI
import UIKit

struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let buttonTitle: String
}

struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var currentPage = 0

    /// Pages after the Stitch hero (glass & grid style from DESIGN.md).
    private let followPages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "🎉🕺💃",
            title: "Instant Fun\nAnywhere!",
            subtitle: "Game night, road trip, or\neven an awkward first meeting —\nFakeit breaks the ice and\nbrings the fun",
            backgroundColor: Color.brightGreenStitch,
            buttonTitle: "I'm In!"
        ),
        OnboardingPage(
            emoji: "🧑‍🍳🥕👨‍🔧",
            title: "Who's Faking It?",
            subtitle: "One of you is lying.\nThe rest know the word.\nCan you spot the imposter\nbefore it's too late?",
            backgroundColor: Color.actionRedStitch,
            buttonTitle: "Got It"
        )
    ]

    private var totalPages: Int { 1 + followPages.count }

    var body: some View {
        ZStack {
            Group {
                if currentPage == 0 {
                    stitchFirstOnboardingPage
                } else if currentPage - 1 < followPages.count {
                    classicOnboardingPage(followPages[currentPage - 1])
                } else {
                    stitchFirstOnboardingPage
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: currentPage)
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Stitch first screen (blueprint / 3D hero)

    private var stitchFirstOnboardingPage: some View {
        ZStack {
            // Stage lighting (radial) + deep night base — Stitch “toy-box” depth
            LinearGradient(
                colors: [
                    Color.stitchElectricPurple.opacity(0.38),
                    Color.stitchNightBase,
                    Color(red: 0.04, green: 0.03, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.stitchElectricPurple.opacity(0.28),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()

            // Blueprint grid (glass & grid)
            BlueprintGridOverlay(lineColor: Color.stitchElectricPurple.opacity(0.22), spacing: 28)

            // Floating technical sketches
            BlueprintSketchOverlay()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 36)

                // Hero (bundled PNG — character + speech bubble in art)
                if let uiImage = UIImage(named: "OnboardingHero") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 12)
                } else {
                    Text("🧓🌵🎤")
                        .font(.evolventa(size: 72))
                }

                Spacer()
                    .frame(minHeight: 12, maxHeight: 28)

                Text("Talk Smarter")
                    .font(.evolventa(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .multilineTextAlignment(.center)

                Text("Guess Better")
                    .font(.evolventa(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 14)

                Text("Describe the secret word without saying it.\nBut beware — the imposter is listening and trying to blend in")
                    .font(.evolventa(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 28)

                Spacer(minLength: 8)

                // Primary CTA — deep onyx + electric purple glow (DESIGN.md)
                Button(action: { advanceFromOnboarding() }) {
                    Text("Let's Play!")
                        .font(.evolventa(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.stitchDeepOnyx)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.stitchElectricPurple.opacity(0.95), lineWidth: 2)
                        )
                        .shadow(color: Color.stitchElectricPurple.opacity(0.75), radius: 16, y: 4)
                        .shadow(color: Color.stitchElectricPurple.opacity(0.45), radius: 28, y: 0)
                }
                .buttonStyle(OnboardingSquishButtonStyle())
                .padding(.horizontal, 36)
                .padding(.bottom, 44)
            }
        }
    }

    // MARK: - Classic follow-up pages

    @ViewBuilder
    private func classicOnboardingPage(_ page: OnboardingPage) -> some View {
        ZStack {
            page.backgroundColor
                .ignoresSafeArea()
                .overlay(
                    GridPatternView(lineColor: .white.opacity(0.35))
                        .opacity(0.15)
                )

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                Text(page.emoji)
                    .font(.evolventa(size: 80))
                    .padding(.bottom, 40)

                Spacer()

                Text(page.title)
                    .font(.evolventa(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                Text(page.subtitle)
                    .font(.evolventa(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                Button(action: { advanceFromOnboarding() }) {
                    Text(page.buttonTitle)
                        .font(.evolventa(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.stitchDeepOnyx)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.stitchElectricPurple.opacity(0.7), lineWidth: 1.5)
                        )
                        .shadow(color: Color.stitchElectricPurple.opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(OnboardingSquishButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }

    private func advanceFromOnboarding() {
        HapticsManager.impact(.light)
        if currentPage < totalPages - 1 {
            currentPage += 1
        } else {
            subscriptionManager.hasCompletedOnboarding = true
            let next = subscriptionManager.isPremium ? "player_setup" : "paywall"
            AnalyticsService.logEvent("onboarding_complete", parameters: ["next": next])
            if subscriptionManager.isPremium {
                router.navigate(to: .playerSetup)
            } else {
                router.navigate(to: .paywall)
            }
        }
    }
}

// MARK: - Blueprint grid (purple graph paper)

struct GridPatternView: View {
    var lineColor: Color = .white.opacity(0.3)

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
    }
}

private struct BlueprintGridOverlay: View {
    var lineColor: Color
    var spacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Decorative blueprint sketches

private struct BlueprintSketchOverlay: View {
    var body: some View {
        Canvas { context, size in
            let faint = Color.stitchElectricPurple.opacity(0.12)
            let strokeStyle = StrokeStyle(lineWidth: 1, dash: [6, 5])

            // Circles
            for i in 0..<4 {
                let r = CGFloat(40 + i * 55)
                let rect = CGRect(
                    x: size.width * 0.65 - r * 0.5,
                    y: CGFloat(80 + i * 22),
                    width: r,
                    height: r
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(faint),
                    style: strokeStyle
                )
            }

            // Cross-hatched rectangle
            var rectPath = Path()
            rectPath.addRoundedRect(
                in: CGRect(x: size.width * 0.06, y: size.height * 0.18, width: 72, height: 56),
                cornerSize: CGSize(width: 8, height: 8)
            )
            context.stroke(rectPath, with: .color(faint), lineWidth: 1)

            // Diagonal hatch
            for o in stride(from: -40, through: 80, by: 14) {
                var h = Path()
                h.move(to: CGPoint(x: size.width * 0.06 + CGFloat(o), y: size.height * 0.18))
                h.addLine(to: CGPoint(x: size.width * 0.06 + CGFloat(o) + 40, y: size.height * 0.18 + 56))
                context.stroke(h, with: .color(faint.opacity(0.8)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Interaction

private struct OnboardingSquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension Color {
    /// DESIGN.md — Success / Fresh #24D330
    fileprivate static let brightGreenStitch = Color(red: 0.141, green: 0.827, blue: 0.188)
    /// DESIGN.md — Action / Vivid Red #FF3B30
    fileprivate static let actionRedStitch = Color(red: 1.0, green: 0.231, blue: 0.188)
}
