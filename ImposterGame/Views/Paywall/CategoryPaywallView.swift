import Adapty
import AdaptyUI
import SwiftUI

/// Thin wrapper that presents the Adapty Flow ("Premium Paywall") for the `category_paywall`
/// placement. See `OnboardingPaywallView` for the general shape - the Flow renders its own UI,
/// this view fetches+presents it and wires its events into existing analytics/navigation.
struct CategoryPaywallView: View {
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
                        subscriptionManager.handleFlowProductSelected(product: product, context: .category)
                    },
                    didStartPurchase: { product in
                        subscriptionManager.handleFlowPurchaseStarted(product: product, context: .category)
                    },
                    didFinishPurchase: handlePurchaseFinished,
                    didFailPurchase: handlePurchaseFailed,
                    didStartRestore: {
                        subscriptionManager.handleFlowRestoreStarted(context: .category)
                    },
                    didFinishRestore: handleRestoreFinished,
                    didFailRestore: handleRestoreFailed,
                    didReceiveError: { _ in closePaywall(reason: .skip) }
                )
            } else if loadFailed {
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

    /// The "shown" bookkeeping lives here, not in `onAppear`: none of these flags are true until
    /// the flow has actually rendered, and on a failed load the user only ever saw a spinner.
    private func loadFlow() async {
        do {
            let flow = try await Adapty.getFlow(placementId: AppConstants.AdaptyPlacement.categoryPaywall)
            try? await Adapty.logShowFlow(flow)
            flowConfiguration = try await AdaptyUI.getFlowConfiguration(forFlow: flow)

            // Only count this as "saw the category paywall" for the post-game fatigue exclusion
            // when it's a genuine in-app trigger (tapped a locked category, pushed on top of
            // [.playerSetup, .categories]). When reached directly from the loader (returning user,
            // path.count <= 1) it's functionally this session's FIRST-touch paywall, not a repeat
            // ask - it must not poison the same-session flag and block the post-game offer.
            if router.path.count > 1 {
                subscriptionManager.hasSeenCategoryPaywallThisSession = true
            }
            subscriptionManager.markPaywallShown()
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsService.logPaywallViewed(context: .category)
            }
        } catch {
            print("CategoryPaywallView: failed loading flow - \(error)")
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
            subscriptionManager.handleFlowLinkTapped(url: url, context: .category)
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
            context: .category
        )
        if didGrantAccess {
            closePaywall(reason: .purchaseSuccess)
        }
    }

    private func handlePurchaseFailed(product: AdaptyPaywallProduct, error: AdaptyError) {
        subscriptionManager.handleFlowPurchaseFailed(product: product, error: error, context: .category)
    }

    private func handleRestoreFinished(profile: AdaptyProfile) {
        let outcome = subscriptionManager.handleFlowRestoreFinished(profile: profile, context: .category)
        if outcome == .restored {
            closePaywall(reason: .purchaseSuccess)
        }
    }

    private func handleRestoreFailed(error: AdaptyError) {
        subscriptionManager.handleFlowRestoreFailed(error: error, context: .category)
    }

    private func closePaywall(reason: AnalyticsService.PaywallCloseReason) {
        guard !didClosePaywall else { return }
        didClosePaywall = true

        if didLogPaywallViewed {
            AnalyticsService.logPaywallClosed(context: .category, reason: reason)
        }
        // count <= 1 means this paywall itself is the only thing on the stack - reached directly
        // from the loader (returning non-premium user who already completed onboarding earlier),
        // not pushed from CategoriesView on top of [.playerSetup, .categories]. `path.isEmpty`
        // would never be true here since this screen is always on the path while it's shown.
        if router.path.count <= 1 {
            // This IS that user's first-touch paywall pitch this app-lifetime (onboarding itself
            // was skipped for them) - declining it should make them eligible for the post-game
            // offer just like declining OnboardingPaywallView does, not just declining a locked
            // category later (which must NOT set this, or the post-game paywall would fire for
            // ordinary category-paywall bounces too). A flow that never rendered is not a decline.
            if reason != .purchaseSuccess, didLogPaywallViewed {
                subscriptionManager.hasDeclinedOnboardingPaywall = true
            }
            router.navigateToPlayerSetup()
            return
        }
        router.pop()
    }
}
