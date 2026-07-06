import StoreKit
import UIKit

/// Presents the native App Store review prompt, at most once every ~4 months (Apple allows ~3×/year).
enum RateUsService {
    private static let lastRatePromptDateKey = "lastRatePromptDate"
    private static let legacyOnboardingPromptKey = "hasPresentedOnboardingRatePrompt"
    private static let completedGamesCountKey = "completedGamesCount"

    /// Minimum spacing between prompt attempts (~4 months, aligned with Apple's ~3×/year cap).
    private static let minimumMonthsBetweenPrompts = 4

    /// Call when a round finishes. Shows the review prompt once, after the first completed game.
    static func requestReviewAfterFirstGameIfNeeded() {
        let completedGames = recordCompletedGame()
        guard completedGames == 1 else { return }
        requestReviewIfNeeded(context: "first_game_completed")
    }

    private static func requestReviewIfNeeded(context: String) {
        migrateLegacyFlagIfNeeded()
        guard isEligibleForPrompt else { return }

        recordPromptAttempt()
        AnalyticsService.logEvent("rate_us_requested", parameters: [
            "context": context
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
            else { return }

            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private static var isEligibleForPrompt: Bool {
        guard let lastAttempt = lastRatePromptDate else { return true }
        guard let nextEligible = Calendar.current.date(
            byAdding: .month,
            value: minimumMonthsBetweenPrompts,
            to: lastAttempt
        ) else { return false }
        return Date() >= nextEligible
    }

    private static var lastRatePromptDate: Date? {
        let timestamp = UserDefaults.standard.double(forKey: lastRatePromptDateKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private static func recordPromptAttempt() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastRatePromptDateKey)
    }

    private static func recordCompletedGame() -> Int {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: completedGamesCountKey) + 1
        defaults.set(count, forKey: completedGamesCountKey)
        return count
    }

    /// Users who already saw the one-time onboarding prompt get a baseline date so the 4-month cycle starts from this update.
    private static func migrateLegacyFlagIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: lastRatePromptDateKey) == nil else { return }
        guard defaults.bool(forKey: legacyOnboardingPromptKey) else { return }
        recordPromptAttempt()
    }

    #if DEBUG
    static func resetRatePromptForQA() {
        UserDefaults.standard.removeObject(forKey: lastRatePromptDateKey)
        UserDefaults.standard.removeObject(forKey: legacyOnboardingPromptKey)
        UserDefaults.standard.removeObject(forKey: completedGamesCountKey)
    }

    static func simulateEligibleForQA() {
        let past = Calendar.current.date(byAdding: .month, value: -(minimumMonthsBetweenPrompts + 1), to: Date()) ?? Date()
        UserDefaults.standard.set(past.timeIntervalSince1970, forKey: lastRatePromptDateKey)
    }
    #endif
}
