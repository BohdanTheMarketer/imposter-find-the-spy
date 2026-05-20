import SwiftUI

/// Shared `navigationDestination` body for `AppScreen` (normal app + screenshot harness).
struct AppNavigationDestinationView: View {
    let screen: AppScreen
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .topLeading) {
            destinationContent

            if AppStoreScreenshotMode.isEnabled {
                screenshotHarnessBackChrome
            }
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch screen {
        case .onboarding:
            OnboardingView()
        case .paywall:
            OnboardingPaywallView()
        case .categoryPaywall:
            CategoryPaywallView()
        case .playerSetup:
            PlayerSetupView()
        case .categories:
            CategoriesView()
        case .gameSettings:
            GameSettingsView()
        case .roleReveal:
            RoleRevealView()
        case .gameTimer:
            GameTimerView()
        case .voting:
            VotingView()
        case .result:
            ResultView()
        }
    }

    /// Invisible tap target (top-trailing): full-screen flows hide the nav bar, so swipe-back is unreliable.
    private var screenshotHarnessBackChrome: some View {
        GeometryReader { geo in
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        HapticsManager.impact(.light)
                        router.popToRoot()
                    } label: {
                        Color.clear
                            .frame(width: 96, height: 56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to screenshot harness menu")
                }
                .padding(.trailing, 6)
                .padding(.top, geo.safeAreaInsets.top + 4)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(true)
        .zIndex(999_999)
    }
}
