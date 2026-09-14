import Adapty
import AdaptyUI
import SwiftUI

/// Thin wrapper that presents the Adapty Flow ("Premium Paywall") for the `onboarding` placement.
/// The Flow renders its own title/benefits/plan picker/CTA/restore link server-side via AdaptyUI -
/// this view's job is only to fetch+present it and translate its event callbacks into the app's
/// existing analytics + navigation/state-flag bookkeeping.
struct OnboardingPaywallView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL

    @State private var flowConfiguration: AdaptyUI.FlowConfiguration?
    @State private var didClosePaywall = false
    @State private var didLogPaywallViewed = false
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            LinearGradient.appPurpleGradient
                .ignoresSafeArea()

            if let flowConfiguration {
                AdaptyFlowView(
                    flowConfiguration: flowConfiguration,
                    didPerformAction: handleAction,
                    didSelectProduct: { product in
                        subscriptionManager.handleFlowProductSelected(product: product, context: .onboarding)
                    },
                    didStartPurchase: { product in
                        subscriptionManager.handleFlowPurchaseStarted(product: product, context: .onboarding)
                    },
                    didFinishPurchase: handlePurchaseFinished,
                    didFailPurchase: handlePurchaseFailed,
                    didStartRestore: {
                        subscriptionManager.handleFlowRestoreStarted(context: .onboarding)
                    },
                    didFinishRestore: handleRestoreFinished,
                    didFailRestore: handleRestoreFailed,
                    didReceiveError: { _ in closePaywall(reason: .skip) }
                )
            } else if loadFailed {
                // Flow failed to load (e.g. no network) - don't trap the user on a blank screen.
                Color.clear.onAppear { closePaywall(reason: .skip) }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if subscriptionManager.isPremium {
                closePaywall(reason: .purchaseSuccess)
                return
            }
            Task { await loadFlow() }
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            guard isPremium else { return }
            closePaywall(reason: .purchaseSuccess)
        }
    }

    /// The "shown" bookkeeping lives here, not in `onAppear`: `markPaywallShown()` burns the
    /// first-impression flag and `paywall_viewed` claims an impression, neither of which is true
    /// until the flow has actually rendered. On a failed load the user only ever saw a spinner.
    private func loadFlow() async {
        do {
            let flow = try await Adapty.getFlow(placementId: AppConstants.AdaptyPlacement.onboarding)
            try? await Adapty.logShowFlow(flow)
            flowConfiguration = try await AdaptyUI.getFlowConfiguration(forFlow: flow)

            subscriptionManager.markPaywallShown()
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsService.logPaywallViewed(context: .onboarding)
            }
        } catch {
            print("OnboardingPaywallView: failed loading flow - \(error)")
            loadFailed = true
        }
    }

    private static let dismissingCustomActionIDs = [
        "close", "skip", "dismiss", "cancel", "later", "not_now", "notnow"
    ]

    private func handleAction(_ action: AdaptyUI.Action) {
        switch action {
        case .close:
            closePaywall(reason: .closeButton)
        case .openURL(let url, _):
            subscriptionManager.handleFlowLinkTapped(url: url, context: .onboarding)
            openURL(url)
        case .custom(let id):
            // The Flow is authored in a dashboard this build has no control over. If a
            // dismissal control there is ever wired as a custom action instead of the
            // built-in Close, honouring it is the difference between an exit and a trap -
            // the nav bar is hidden, so Close is otherwise the only way out.
            if Self.dismissingCustomActionIDs.contains(where: id.lowercased().contains) {
                closePaywall(reason: .closeButton)
            }
        }
    }

    private func handlePurchaseFinished(product: AdaptyPaywallProduct, result: AdaptyPurchaseResult) {
        // Close only when paid access is actually active - a `.success` whose profile has no
        // access level yet would otherwise dismiss the paywall onto locked content.
        let didGrantAccess = subscriptionManager.handleFlowPurchaseFinished(
            product: product,
            result: result,
            context: .onboarding
        )
        if didGrantAccess {
            closePaywall(reason: .purchaseSuccess)
        }
    }

    private func handlePurchaseFailed(product: AdaptyPaywallProduct, error: AdaptyError) {
        subscriptionManager.handleFlowPurchaseFailed(product: product, error: error, context: .onboarding)
    }

    private func handleRestoreFinished(profile: AdaptyProfile) {
        let outcome = subscriptionManager.handleFlowRestoreFinished(profile: profile, context: .onboarding)
        if outcome == .restored {
            closePaywall(reason: .purchaseSuccess)
        }
    }

    private func handleRestoreFailed(error: AdaptyError) {
        subscriptionManager.handleFlowRestoreFailed(error: error, context: .onboarding)
    }

    private func closePaywall(reason: AnalyticsService.PaywallCloseReason) {
        guard !didClosePaywall else { return }
        didClosePaywall = true

        // "Declined" requires having actually seen the offer. A flow that failed to load (offline)
        // dismisses through here too, and marking that as a decline permanently suppresses the
        // pitch - and, via isEligibleForPostGamePaywall, mis-targets the post-game one as well.
        if reason != .purchaseSuccess, didLogPaywallViewed {
            subscriptionManager.hasDeclinedOnboardingPaywall = true
        }

        guard didLogPaywallViewed else {
            router.navigateToPlayerSetup()
            return
        }

        AnalyticsService.logPaywallClosed(context: .onboarding, reason: reason)
        // Paywall now shows before player setup - players haven't been entered yet, so route
        // there next instead of skipping ahead to categories.
        router.navigateToPlayerSetup()
    }
}
