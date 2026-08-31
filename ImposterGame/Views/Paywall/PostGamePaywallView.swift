import SwiftUI

/// Soft, dismissible paywall shown once, right after a user's first completed game -
/// only to users who saw and declined the onboarding paywall and haven't purchased.
/// Presented as a `.sheet`, not a router push, so it never blocks the game flow.
struct PostGamePaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var didFinish = false
    @State private var didLogPaywallViewed = false
    @State private var showRestoreMessage = false
    @State private var restoreResultMessageKey = "paywall.restore_alert_message"
    @State private var showPurchaseIssueMessage = false
    @State private var purchaseIssueMessageKey = "paywall.purchase_pending_message"

    private enum PostGamePaywallLinks {
        static let privacyURL = URL(string: "https://www.verte-bro.com/privacy-policy")
        static let termsURL = URL(string: "https://www.verte-bro.com/terms-and-conditions")
    }

    private var isContinueDisabled: Bool {
        subscriptionManager.isPurchasing || !subscriptionManager.isPriceLoaded(for: .weekly)
    }

    var body: some View {
        ZStack {
            LinearGradient.appPurpleGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView(lineColor: .white.opacity(0.14))
                        .opacity(0.5)
                )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text("paywall.postgame.headline")
                            .font(.antropicSans(size: 28, weight: .heavy))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("paywall.postgame.subheadline")
                            .font(.antropicSerif(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    PaywallTrialTimelineView(
                        billedWeeklyPrice: subscriptionManager.weeklyPlanWeeklyPriceText
                    )
                    .padding(.vertical, 6)

                    PaywallSingleLineCTAButton(
                        titleKey: "paywall.postgame.cta_subordinate",
                        action: handleContinueTapped,
                        isLoading: isContinueDisabled
                    )

                    footerLinks

                    Text(verbatim: subscriptionManager.displayTerms(for: .weekly))
                        .font(.antropicSerif(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .alert(
            String(localized: "paywall.restore_alert_title"),
            isPresented: $showRestoreMessage
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(restoreResultMessageKey))
        }
        .alert(
            String(localized: "paywall.purchase_issue_alert_title"),
            isPresented: $showPurchaseIssueMessage
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(purchaseIssueMessageKey))
        }
        .presentationDetents([.fraction(0.45), .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            subscriptionManager.markPostGamePaywallShown()
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsService.logPaywallViewed(context: .postGame)
            }
            Task {
                await subscriptionManager.refreshStoreProducts(trigger: "postgame_paywall_appear")
            }
        }
        .onDisappear {
            guard !didFinish else { return }
            didFinish = true
            AnalyticsService.logPaywallClosed(context: .postGame, reason: .skip)
        }
        .onChange(of: subscriptionManager.isPremium) { isPremium in
            guard isPremium else { return }
            finish(reason: .purchaseSuccess)
        }
    }

    private func handleContinueTapped() {
        guard !isContinueDisabled else { return }
        HapticsManager.impact(.medium)
        AnalyticsService.logPaywallContinueTapped(
            context: .postGame,
            plan: PaywallCopy.analyticsPlanName(for: .weekly),
            trialEnabled: subscriptionManager.isEligibleForTrial
        )
        Task {
            switch await subscriptionManager.purchaseSubscription(plan: .weekly, context: .postGame) {
            case .success:
                finish(reason: .purchaseSuccess)
            case .userCancelled:
                break
            case .pending:
                purchaseIssueMessageKey = "paywall.purchase_pending_message"
                showPurchaseIssueMessage = true
            case .failed:
                purchaseIssueMessageKey = "paywall.purchase_error_message"
                showPurchaseIssueMessage = true
            }
        }
    }

    private func handleRestoreTapped() {
        AnalyticsService.logPaywallRestoreTapped(context: .postGame)
        Task {
            switch await subscriptionManager.restorePurchases(context: .postGame) {
            case .restored:
                break
            case .noPurchasesFound:
                restoreResultMessageKey = "paywall.restore_alert_message"
                showRestoreMessage = true
            case .failed:
                restoreResultMessageKey = "paywall.restore_error_message"
                showRestoreMessage = true
            }
        }
    }

    private func finish(reason: AnalyticsService.PaywallCloseReason) {
        guard !didFinish else { return }
        didFinish = true
        AnalyticsService.logPaywallClosed(context: .postGame, reason: reason)
        dismiss()
    }

    private var footerLinks: some View {
        HStack(spacing: 26) {
            Button(String(localized: "legal.terms_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .postGame, linkType: "terms")
                if let url = PostGamePaywallLinks.termsURL {
                    openURL(url)
                }
            }
            Button(String(localized: "legal.privacy_short")) {
                AnalyticsService.logPaywallLinkTapped(context: .postGame, linkType: "privacy")
                if let url = PostGamePaywallLinks.privacyURL {
                    openURL(url)
                }
            }
            Button(action: handleRestoreTapped) {
                if subscriptionManager.isRestoring {
                    ProgressView()
                        .tint(.white.opacity(0.5))
                } else {
                    Text(String(localized: "paywall.restore"))
                }
            }
            .disabled(subscriptionManager.isRestoring)
            Button(String(localized: "paywall.postgame.not_now")) {
                finish(reason: .skip)
            }
        }
        .font(.antropicSerif(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.5))
    }
}
