import StoreKit
import UIKit

/// Presents the native App Store review prompt, at most once every ~4 months (Apple allows ~3×/year).
enum RateUsService {
    private static let lastRatePromptDateKey = "lastRatePromptDate"
    private static let legacyOnboardingPromptKey = "hasPresentedOnboardingRatePrompt"

    /// Minimum spacing between prompt attempts (~4 months, aligned with Apple's ~3×/year cap).
    private static let minimumMonthsBetweenPrompts = 4

    static func requestOnboardingReviewIfNeeded() {
        requestReviewIfNeeded(context: "onboarding_last_page")
    }

    static func requestReviewIfNeeded(context: String = "app_active") {
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
    }

    static func simulateEligibleForQA() {
        let past = Calendar.current.date(byAdding: .month, value: -(minimumMonthsBetweenPrompts + 1), to: Date()) ?? Date()
        UserDefaults.standard.set(past.timeIntervalSince1970, forKey: lastRatePromptDateKey)
    }
    #endif
}
