import Adapty
import AdaptyUI
import SwiftUI

/// Soft, dismissible paywall shown to non-premium players after every completed game - on the
/// result screen itself, or, when that round's rate-us prompt got there first, in front of the
/// next "Play Again" tap (see `ResultView.resolvePostRoundOverlay`).
/// Presented as a `.fullScreenCover`, not a router push, so it reads as a full-page offer
/// (like the onboarding paywall) while still returning to the result screen on dismissal.
/// Note there's no swipe-to-dismiss at this presentation size - the flow's own close control
/// is the way out, which is why `handleAction` below treats dismissal so defensively.
///
/// Thin wrapper around the Adapty Flow for the `post_game` placement - see
/// `OnboardingPaywallView` for the general shape.
struct PostGamePaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var flowConfiguration: AdaptyUI.FlowConfiguration?
    @State private var didFinish = false
    @State private var didLogPaywallViewed = false
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            if let flowConfiguration {
                AdaptyFlowView(
                    flowConfiguration: flowConfiguration,
                    didPerformAction: handleAction,
                    didSelectProduct: { product in
                        subscriptionManager.handleFlowProductSelected(product: product, context: .postGame)
                    },
                    didStartPurchase: { product in
                        subscriptionManager.handleFlowPurchaseStarted(product: product, context: .postGame)
                    },
                    didFinishPurchase: handlePurchaseFinished,
                    didFailPurchase: handlePurchaseFailed,
                    didStartRestore: {
                        subscriptionManager.handleFlowRestoreStarted(context: .postGame)
                    },
                    didFinishRestore: handleRestoreFinished,
                    didFailRestore: handleRestoreFailed,
                    didReceiveError: { _ in finish(reason: .skip) }
                )
            } else if loadFailed {
                Color.clear.onAppear { finish(reason: .skip) }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            Task { await loadFlow() }
        }
        .onDisappear {
            guard !didFinish else { return }
            didFinish = true
            guard didLogPaywallViewed else { return }
            AnalyticsService.logPaywallClosed(context: .postGame, reason: .skip)
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            guard isPremium else { return }
            finish(reason: .purchaseSuccess)
        }
    }

    /// `paywall_viewed` is logged here rather than in `onAppear` because that would count spinners
    /// that got dismissed before the flow ever rendered, deflating every conversion rate.
    private func loadFlow() async {
        do {
            let flow = try await Adapty.getFlow(placementId: AppConstants.AdaptyPlacement.postGame)
            try? await Adapty.logShowFlow(flow)
            flowConfiguration = try await AdaptyUI.getFlowConfiguration(forFlow: flow)

            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsService.logPaywallViewed(context: .postGame)
            }
        } catch {
            print("PostGamePaywallView: failed loading flow - \(error)")
            loadFailed = true
        }
    }

    private static let dismissingCustomActionIDs = [
        "close", "skip", "dismiss", "cancel", "later", "not_now", "notnow"
    ]

    private func handleAction(_ action: AdaptyUI.Action) {
        switch action {
        case .close:
            finish(reason: .closeButton)
        case .openURL(let url, _):
            subscriptionManager.handleFlowLinkTapped(url: url, context: .postGame)
            openURL(url)
        case .custom(let id):
            // The Flow is authored in a dashboard this build has no control over. If a
            // dismissal control there is ever wired as a custom action instead of the
            // built-in Close, honouring it is the difference between an exit and a trap -
            // the nav bar is hidden, so Close is otherwise the only way out.
            if Self.dismissingCustomActionIDs.contains(where: id.lowercased().contains) {
                finish(reason: .closeButton)
            }
        }
    }

    private func handlePurchaseFinished(product: AdaptyPaywallProduct, result: AdaptyPurchaseResult) {
        // Close only when paid access is actually active - a `.success` whose profile has no
        // access level yet would otherwise dismiss the paywall onto locked content.
        let didGrantAccess = subscriptionManager.handleFlowPurchaseFinished(
            product: product,
            result: result,
            context: .postGame
        )
        if didGrantAccess {
            finish(reason: .purchaseSuccess)
        }
    }

    private func handlePurchaseFailed(product: AdaptyPaywallProduct, error: AdaptyError) {
        subscriptionManager.handleFlowPurchaseFailed(product: product, error: error, context: .postGame)
    }

    private func handleRestoreFinished(profile: AdaptyProfile) {
        let outcome = subscriptionManager.handleFlowRestoreFinished(profile: profile, context: .postGame)
        if outcome == .restored {
            finish(reason: .purchaseSuccess)
        }
    }

    private func handleRestoreFailed(error: AdaptyError) {
        subscriptionManager.handleFlowRestoreFailed(error: error, context: .postGame)
    }

    private func finish(reason: AnalyticsService.PaywallCloseReason) {
        guard !didFinish else { return }
        didFinish = true
        // No "closed" without a matching "viewed" - a flow that never rendered was never a paywall
        // impression, and pairing the two keeps close-rate denominators honest.
        if didLogPaywallViewed {
            AnalyticsService.logPaywallClosed(context: .postGame, reason: reason)
        }
        dismiss()
    }
}
