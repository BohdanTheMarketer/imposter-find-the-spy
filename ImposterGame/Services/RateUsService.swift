import StoreKit
import UIKit

/// Presents the native App Store review prompt (one-time on last onboarding page).
enum RateUsService {
    private static let onboardingPromptKey = "hasPresentedOnboardingRatePrompt"

    static var hasPresentedOnboardingRatePrompt: Bool {
        UserDefaults.standard.bool(forKey: onboardingPromptKey)
    }

    /// Requests the system review dialog once when the user reaches the last onboarding screen.
    static func requestOnboardingReviewIfNeeded() {
        guard !hasPresentedOnboardingRatePrompt else { return }

        UserDefaults.standard.set(true, forKey: onboardingPromptKey)
        AnalyticsService.logEvent("rate_us_requested", parameters: [
            "context": "onboarding_last_page"
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

    #if DEBUG
    /// Clears the one-time flag for manual QA on onboarding page 3.
    static func resetOnboardingRatePromptForQA() {
        UserDefaults.standard.removeObject(forKey: onboardingPromptKey)
    }
    #endif
}
