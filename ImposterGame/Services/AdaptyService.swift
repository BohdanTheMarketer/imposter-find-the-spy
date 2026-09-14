import Adapty
import Foundation

@MainActor
final class AdaptyService: NSObject, ObservableObject, AdaptyDelegate {
    static let shared = AdaptyService()

    @Published var profile: AdaptyProfile?

    var isPremiumUser: Bool {
        profile?.accessLevels[AppConstants.adaptyAccessLevelId]?.isActive ?? false
    }

    /// A failed fetch (SDK still activating, offline, profile swapped mid-flight by `identify`)
    /// leaves the last known profile in place. Publishing `nil` instead would read downstream as
    /// "this user has no subscription" and revoke a paying user's access.
    func reloadProfile() async {
        guard let freshProfile = try? await Adapty.getProfile() else { return }
        profile = freshProfile
    }

    /// `AdaptyDelegate` is not main-actor isolated, so this callback arrives on whatever queue the
    /// SDK uses. Declaring it `nonisolated` and hopping explicitly keeps the conformance legal
    /// under Swift 6's concurrency checking instead of relying on an implicit, unsound hop.
    nonisolated func didLoadLatestProfile(_ profile: AdaptyProfile) {
        Task { @MainActor in
            self.profile = profile
        }
    }
}
