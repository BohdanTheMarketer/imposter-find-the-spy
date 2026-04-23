import FirebaseCore
import SwiftUI

@main
struct ImposterGameApp: App {
    init() {
        AppFontRegistrar.registerAppFonts()
        FirebaseApp.configure()
    }

    @StateObject private var router = AppRouter()
    @StateObject private var gameSession = GameSession()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                LoaderView()
                    .navigationDestination(for: AppScreen.self) { screen in
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
            }
            .environmentObject(router)
            .environmentObject(gameSession)
            .environmentObject(subscriptionManager)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task {
                    await subscriptionManager.refreshSubscriptionStatus()
                }
            }
        }
    }
}
