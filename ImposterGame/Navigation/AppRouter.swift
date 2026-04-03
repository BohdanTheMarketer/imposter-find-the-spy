import SwiftUI

enum AppScreen: String, Hashable {
    case onboarding
    case paywall
    case categoryPaywall
    case playerSetup
    case categories
    case gameSettings
    case roleReveal
    case gameTimer
    case voting
    case result
}

class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to screen: AppScreen) {
        path.append(screen)
        AnalyticsService.logScreenView(for: screen)
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Navigate back to player setup (new game / play again)
    func navigateToPlayerSetup() {
        var next = NavigationPath()
        next.append(AppScreen.playerSetup)
        path = next
        AnalyticsService.logScreenView(for: .playerSetup)
    }

    /// Player setup → categories (same players; new game / pick category again)
    func navigateToCategories() {
        var next = NavigationPath()
        next.append(AppScreen.playerSetup)
        next.append(AppScreen.categories)
        path = next
        AnalyticsService.logScreenView(for: .categories)
    }
}
