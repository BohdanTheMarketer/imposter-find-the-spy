import SwiftUI

enum AppScreen: Hashable {
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
        path = NavigationPath()
        path.append(AppScreen.playerSetup)
    }

    /// Navigate back to categories (play again with same players)
    func navigateToCategories() {
        path = NavigationPath()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.path.append(AppScreen.playerSetup)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.path.append(AppScreen.categories)
            }
        }
    }
}
