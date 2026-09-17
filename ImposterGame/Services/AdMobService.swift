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

    private var interstitial: InterstitialAd?
    private var isLoadingInterstitial = false
    private var dismissContinuation: CheckedContinuation<Void, Never>?

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
        """
    }

    private override init() {}

    func start() {
        if !testDeviceIdentifiers.isEmpty {
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIdentifiers
        }
        MobileAds.shared.start(completionHandler: nil)
        Task { await loadInterstitial() }
    }

    /// Presents the preloaded interstitial and suspends until it's dismissed (or failed to
    /// present), so callers can sequence what happens next. If nothing is ready yet, returns
    /// immediately - after kicking off a background load for next time - rather than blocking the
    /// caller on a network fetch.
    func showInterstitial() async {
        guard let interstitial, let presenter = Self.topViewController() else {
            Task { await loadInterstitial() }
            return
        }
        self.interstitial = nil
        await withCheckedContinuation { continuation in
            dismissContinuation = continuation
            interstitial.present(from: presenter)
        }
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
