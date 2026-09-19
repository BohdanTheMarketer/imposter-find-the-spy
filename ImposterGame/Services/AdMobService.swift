import GoogleMobileAds
import UIKit

/// Loads and shows a single interstitial ad slot, used after "Play Again" for non-premium users
/// (see `ResultView`). Uses the app's real AdMob interstitial ad unit.
@MainActor
final class AdMobService: NSObject {
    static let shared = AdMobService()

    /// Real production interstitial ad unit (Imposter: Find the Spy, iOS).
    private let interstitialAdUnitID = "ca-app-pub-4116257594190121/7756453047"

    /// Devices that should always receive clearly-labeled TEST ads even when requesting the real
    /// ad unit above - tapping a REAL ad yourself during development risks Google flagging the
    /// AdMob account for invalid traffic. Add a device's identifier here (Xcode's console prints
    /// it on that device's first ad request, in a line like "To get test ads on this device, set:
    /// ... testDeviceIdentifiers = [ \"XXXXXXXX\" ]") before testing with this real ad unit on it.
    private let testDeviceIdentifiers: [String] = []

    /// Per-app-launch cap - resets on relaunch, not persisted, matching "session" as used
    /// elsewhere (e.g. `AnalyticsService`'s session-scoped properties).
    private let maxInterstitialsPerSession = 10
    private let minIntervalBetweenInterstitials: TimeInterval = 120

    /// Completed rounds a new player gets ad-free before the first interstitial is allowed -
    /// a full-screen ad during someone's first games costs more in early retention than it earns.
    private let adFreeCompletedGames = 2

    private var interstitial: InterstitialAd?
    private var isLoadingInterstitial = false
    private var dismissContinuation: CheckedContinuation<Void, Never>?
    private var sessionInterstitialCount = 0
    private var lastInterstitialShownDate: Date?

    /// Surfaced via the `admin_debug_status` QA command - `InterstitialAd.load` failures (no
    /// fill, network, app-ads.txt/verification-related serving limits, etc.) otherwise only ever
    /// hit the console log, invisible on a TestFlight/Release build.
    private(set) var lastLoadErrorDescription: String?
    private(set) var lastLoadAttemptDate: Date?

    var qaDiagnosticSummary: String {
        """
        interstitial ready = \(interstitial != nil)
        last load attempt = \(lastLoadAttemptDate.map { "\($0)" } ?? "never")
        last load error = \(lastLoadErrorDescription ?? "none")
        completed games = \(AnalyticsService.totalGamesPlayed) (ads start above \(adFreeCompletedGames))
        session interstitials shown = \(sessionInterstitialCount)/\(maxInterstitialsPerSession)
        last interstitial shown = \(lastInterstitialShownDate.map { "\($0)" } ?? "never")
        """
    }

    private override init() {}

    func start() {
        if !testDeviceIdentifiers.isEmpty {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIdentifiers
        }
        // The first load has to wait for the SDK to report itself initialized. Firing it
        // alongside `start` instead raced that initialization and came back empty, and since the
        // opening ad-free rounds never call `showInterstitial`, nothing retried until the first
        // eligible round - which then had no ad to present and only kicked off a load for the next.
        MobileAds.shared.start { _ in
            Task { @MainActor in await self.loadInterstitial() }
        }
    }

    /// Presents the preloaded interstitial and suspends until it's dismissed (or failed to
    /// present), so callers can sequence what happens next. Returns `false` without presenting -
    /// never blocking the caller on a network fetch or an ad that isn't allowed to show - when:
    /// the player is still inside their ad-free opening games, the per-session cap has been
    /// reached, we're still inside the minimum spacing window since the last ad, or nothing is
    /// ready yet. Every one of those cases still tops the slot back up for the next round.
    @discardableResult
    func showInterstitial() async -> Bool {
        // Refill first, whichever gate below turns this particular call away - so a round that
        // isn't allowed to present still leaves the next one with something ready.
        if interstitial == nil {
            Task { await loadInterstitial() }
        }
        // `totalGamesPlayed` already counts the round that just ended - ResultView bumps it when
        // the result screen appears, before it gets here.
        guard AnalyticsService.totalGamesPlayed > adFreeCompletedGames else { return false }
        guard sessionInterstitialCount < maxInterstitialsPerSession else { return false }
        if let lastShown = lastInterstitialShownDate,
           Date().timeIntervalSince(lastShown) < minIntervalBetweenInterstitials {
            return false
        }
        guard let interstitial, let presenter = Self.topViewController() else { return false }
        self.interstitial = nil
        sessionInterstitialCount += 1
        lastInterstitialShownDate = Date()
        await withCheckedContinuation { continuation in
            dismissContinuation = continuation
            interstitial.present(from: presenter)
        }
        return true
    }

    private func loadInterstitial() async {
        guard !isLoadingInterstitial, interstitial == nil else { return }
        isLoadingInterstitial = true
        defer { isLoadingInterstitial = false }
        lastLoadAttemptDate = Date()
        do {
            let ad = try await InterstitialAd.load(with: interstitialAdUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            interstitial = ad
            lastLoadErrorDescription = nil
        } catch {
            lastLoadErrorDescription = error.localizedDescription
            print("AdMobService: failed to load interstitial - \(error.localizedDescription)")
        }
    }

    private func resumeDismissContinuation() {
        dismissContinuation?.resume()
        dismissContinuation = nil
    }

    private static func topViewController() -> UIViewController? {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
        guard let root = activeScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

extension AdMobService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        resumeDismissContinuation()
        Task { await loadInterstitial() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AdMobService: failed to present interstitial - \(error.localizedDescription)")
        resumeDismissContinuation()
        Task { await loadInterstitial() }
    }
}
