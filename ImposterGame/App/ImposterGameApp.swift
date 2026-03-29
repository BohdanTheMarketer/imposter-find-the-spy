import SwiftUI

@main
struct ImposterGameApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var gameSession = GameSession()
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                LoaderView()
                    .navigationDestination(for: AppScreen.self) { screen in
                        switch screen {
                        case .onboarding:
                            OnboardingView()
                        case .paywall:
                            PaywallView()
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
            }
            .environmentObject(router)
            .environmentObject(gameSession)
            .environmentObject(subscriptionManager)
            .preferredColorScheme(.dark)
        }
    }
}
