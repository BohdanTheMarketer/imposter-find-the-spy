import Foundation
import SwiftUI

class SubscriptionManager: ObservableObject {
    @Published var isPremium: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenPaywall") var hasSeenPaywall: Bool = false

    func purchaseSubscription() {
        // TODO: Integrate RevenueCat
        // For now, unlock premium for testing
        isPremium = true
    }

    func restorePurchases() {
        // TODO: Integrate RevenueCat restore
    }
}
