import Foundation
import SwiftUI

class SubscriptionManager: ObservableObject {
    @Published var isPremium: Bool = UserDefaults.standard.bool(forKey: "isPremium") {
        didSet { UserDefaults.standard.set(isPremium, forKey: "isPremium") }
    }

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false

    func purchaseSubscription() {
        // TODO: Integrate RevenueCat
        // For now, unlock premium for testing
        AnalyticsService.logEvent("subscription_purchase", parameters: ["source": "in_app"])
        isPremium = true
        hasCompletedOnboarding = true
    }

    func restorePurchases() {
        // TODO: Integrate RevenueCat restore
        AnalyticsService.logEvent("subscription_restore_attempt")
    }
}
