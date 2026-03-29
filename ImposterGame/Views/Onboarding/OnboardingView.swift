import SwiftUI

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

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "🎉🕺💃",
            title: "Instant Fun\nAnywhere!",
            subtitle: "Game night, road trip, or\neven an awkward first meeting —\nFakeit breaks the ice and\nbrings the fun",
            backgroundColor: Color.onboardingGreen,
            buttonTitle: "I'm In!"
        ),
        OnboardingPage(
            emoji: "🧑‍🍳🥕👨‍🔧",
            title: "Who's Faking It?",
            subtitle: "One of you is lying.\nThe rest know the word.\nCan you spot the imposter\nbefore it's too late?",
            backgroundColor: Color.onboardingRed,
            buttonTitle: "Got It"
        ),
        OnboardingPage(
            emoji: "🧓🌵☝️",
            title: "Talk Smarter\nGuess Better",
            subtitle: "Describe the secret word\nwithout saying it.\nBut beware — the imposter is\nlistening and trying to blend in",
            backgroundColor: Color.onboardingBlue,
            buttonTitle: "Let's Play!"
        )
    ]

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    onboardingPageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        ZStack {
            // Grid pattern background
            page.backgroundColor
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.15)
                )

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Character emojis
                Text(page.emoji)
                    .font(.system(size: 80))
                    .padding(.bottom, 40)

                Spacer()

                // Title
                Text(page.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                // Subtitle
                Text(page.subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                // CTA Button
                Button(action: {
                    HapticsManager.impact(.light)
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        subscriptionManager.hasCompletedOnboarding = true
                        router.navigate(to: .paywall)
                    }
                }) {
                    Text(page.buttonTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}

struct GridPatternView: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
            }
        }
    }
}
