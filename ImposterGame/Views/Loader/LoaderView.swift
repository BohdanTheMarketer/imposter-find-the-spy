import SwiftUI
import AVFoundation

// MARK: - LoaderView

/// Splash screen: plays the bundled `splash.mp4` full-screen, then routes to the first real screen.
struct LoaderView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    /// Prevents re-running navigation when NavigationPath briefly resets.
    private static var didScheduleInitialNavigation = false

    /// Navigate even if the video stalls or fails to load.
    private static let fallbackDelay: Double = 8.0

    @State private var player: AVPlayer? = Bundle.main
        .url(forResource: "splash", withExtension: "mp4")
        .map { AVPlayer(url: $0) }

    var body: some View {
        ZStack {
            Color.black
            if let player {
                SplashVideoPlayer(player: player)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .onAppear { start() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
            guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
            navigateOnce()
        }
    }

    private func start() {
        Task {
            await subscriptionManager.refreshSubscriptionStatus()
        }

        if let player {
            player.isMuted = true
            player.seek(to: .zero)
            player.play()
            after(Self.fallbackDelay) { navigateOnce() }
        } else {
            after(0.5) { navigateOnce() }
        }
    }

    private func navigateOnce() {
        guard !Self.didScheduleInitialNavigation else { return }
        Self.didScheduleInitialNavigation = true
        if subscriptionManager.isPremium {
            router.navigate(to: .playerSetup)
        } else if subscriptionManager.hasCompletedOnboarding {
            // Returning non-premium user - skip the onboarding intro (already seen) and go
            // straight to the category-style paywall (daily pricing) instead of re-showing
            // the one-time-only, full-price OnboardingPaywallView.
            router.navigate(to: .categoryPaywall)
        } else {
            router.navigate(to: .onboarding)
        }
    }

    // MARK: - Helpers

    /// Convenience: schedule work on main queue after `seconds`.
    private func after(_ seconds: Double, execute work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

// MARK: - SplashVideoPlayer

/// Bare `AVPlayerLayer` host — no playback controls, aspect-fill to the screen edges.
private struct SplashVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
