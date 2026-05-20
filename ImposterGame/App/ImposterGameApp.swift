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
                Group {
                    #if DEBUG
                    if AppStoreScreenshotMode.isEnabled {
                        AppStoreScreenshotMenuView()
                    } else {
                        LoaderView()
                    }
                    #else
                    LoaderView()
                    #endif
                }
                .navigationDestination(for: AppScreen.self) { screen in
                    AppNavigationDestinationView(screen: screen)
                }
            }
            .environmentObject(router)
            .environmentObject(gameSession)
            .environmentObject(subscriptionManager)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task {
                    await subscriptionManager.refreshStoreProducts(trigger: "scene_active")
                    await subscriptionManager.refreshSubscriptionStatus()
                }
            }
        }
    }
}
