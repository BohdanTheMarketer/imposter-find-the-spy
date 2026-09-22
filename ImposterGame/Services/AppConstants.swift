import Foundation

enum AppConstants {
    static let adaptyPublicKey = "public_live_t8Qkdro6.63hlbbIDrHjSlZcT5Hnn"
    static let adaptyAccessLevelId = "premium"

    enum AdaptyPlacement {
        static let onboarding = "onboarding"
        static let categoryPaywall = "category_paywall"
        static let postGame = "post_game"
        /// Same premium paywall as `onboarding` / `category_paywall`, but with per-day prices.
        /// Shown instead of them once the user has already seen a paywall (see `premiumPaywall`).
        static let paywallPerDay = "paywall_per_day"

        /// First paywall a user ever sees shows full prices (`firstShowPlacement`); every later
        /// one shows the per-day breakdown.
        static func premiumPaywall(firstShowPlacement: String, hasSeenPaywall: Bool) -> String {
            hasSeenPaywall ? paywallPerDay : firstShowPlacement
        }
    }
}
