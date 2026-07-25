import SwiftUI

// MARK: - Typography (Guideline 3.1.2(c): billed amount dominates)

enum PaywallComplianceStyle {
    static let planTitle = Font.antropicSerif(size: 16, weight: .bold)
    static let planSubtitle = Font.antropicSerif(size: 12, weight: .medium)
    static let billedPrice = Font.antropicSerif(size: 26, weight: .bold)
    static let secondaryNote = Font.antropicSerif(size: 12, weight: .medium)
    static let subordinateOpacity: Double = 0.6
}

// MARK: - Plan card body

struct PaywallPlanCardBody: View {
    let title: String
    let subtitle: String
    let billedPrice: String
    let trailingNote: String?
    var subtitleLineLimit: Int? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                    .font(PaywallComplianceStyle.planTitle)
                    .foregroundColor(.white)
                Text(verbatim: subtitle)
                    .font(PaywallComplianceStyle.planSubtitle)
                    .foregroundColor(.white.opacity(PaywallComplianceStyle.subordinateOpacity))
                    .lineLimit(subtitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: billedPrice)
                    .font(PaywallComplianceStyle.billedPrice)
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                if let trailingNote {
                    Text(verbatim: trailingNote)
                        .font(PaywallComplianceStyle.secondaryNote)
                        .foregroundColor(.white.opacity(PaywallComplianceStyle.subordinateOpacity))
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

// MARK: - Trial timeline

struct PaywallTrialTimelineView: View {
    let billedWeeklyPrice: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            timelineColumn(
                systemImage: "lock.open.fill",
                titleKey: "paywall.timeline.today.title",
                subtitleKey: "paywall.timeline.today.subtitle"
            )
            timelineConnector
            timelineColumn(
                systemImage: "bell.fill",
                titleKey: "paywall.timeline.day2.title",
                subtitleKey: "paywall.timeline.day2.subtitle"
            )
            timelineConnector
            timelineColumn(
                systemImage: "creditcard.fill",
                titleKey: "paywall.timeline.day3.title",
                subtitleText: LocalizationService.shared.localizedFormat(
                    "paywall.timeline.day3.subtitle",
                    billedWeeklyPrice
                )
            )
        }
        .padding(.horizontal, 4)
    }

    private var timelineConnector: some View {
        Rectangle()
            .fill(Color.white.opacity(0.35))
            .frame(width: 20, height: 1)
            .padding(.top, 14)
    }

    private func timelineColumn(
        systemImage: String,
        titleKey: String,
        subtitleKey: String
    ) -> some View {
        timelineColumn(
            systemImage: systemImage,
            titleKey: titleKey,
            subtitleText: LocalizationService.shared.localized(subtitleKey)
        )
    }

    private func timelineColumn(
        systemImage: String,
        titleKey: String,
        subtitleText: String
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.18)))
            Text(LocalizedStringKey(titleKey))
                .font(.antropicSerif(size: 11, weight: .bold))
                .foregroundColor(.white)
            Text(verbatim: subtitleText)
                .font(.antropicSerif(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Single-line CTA

struct PaywallSingleLineCTAButton: View {
    let titleKey: String
    let action: () -> Void
    var usesDarkStyle = true

    var body: some View {
        Button(action: action) {
            HStack {
                Text(LocalizedStringKey(titleKey))
                    .font(.antropicSerif(size: 19, weight: .bold))
                    .foregroundColor(usesDarkStyle ? .white : .appTextOnAccent)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.antropicSerif(size: 19, weight: .bold))
                    .foregroundColor(usesDarkStyle ? .white : .appTextOnAccent)
            }
            .padding(.horizontal, 22)
            .frame(height: 60)
            .background(usesDarkStyle ? Color.stitchDeepOnyx : Color.appAccent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Two-line CTA (3.1.2(c): billed amount on top, trial/action subordinate)

struct PaywallDualLineCTAButton: View {
    let billedLine: String
    let subordinateLineKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: billedLine)
                        .font(.antropicSerif(size: 17, weight: .bold))
                        .foregroundColor(.appTextOnAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(LocalizedStringKey(subordinateLineKey))
                        .font(.antropicSerif(size: 13, weight: .medium))
                        .foregroundColor(.appTextOnAccent.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.right")
                    .font(.antropicSerif(size: 17, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.appAccent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selection model

enum PaywallSelection: Equatable {
    case yearly
    case weekly
}

// MARK: - Subscription option card

struct PaywallSubscriptionOptionCard: View {
    let title: String
    let subtitle: String
    let primaryPrice: String
    let secondaryPrice: String?
    let selected: Bool
    let badgeText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title)
                        .font(PaywallComplianceStyle.planTitle)
                        .foregroundColor(.white)
                    Text(verbatim: subtitle)
                        .font(PaywallComplianceStyle.planSubtitle)
                        .foregroundColor(.white.opacity(PaywallComplianceStyle.subordinateOpacity))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(verbatim: primaryPrice)
                        .font(PaywallComplianceStyle.billedPrice)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.85)
                        .lineLimit(1)
                    if let secondaryPrice {
                        Text(verbatim: secondaryPrice)
                            .font(PaywallComplianceStyle.secondaryNote)
                            .foregroundColor(.white.opacity(PaywallComplianceStyle.subordinateOpacity))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(selected ? 0.24 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(selected ? 1.0 : 0.65), lineWidth: selected ? 2.5 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if let badgeText {
                    Text(verbatim: badgeText)
                        .font(.antropicSerif(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .offset(x: -10, y: -10)
                        .zIndex(2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PaywallPlansSection: View {
    @Binding var selection: PaywallSelection
    let subscriptionManager: SubscriptionManager
    let onSelectionChanged: (PaywallSelection) -> Void
    /// When `true` (repeat paywall views), the headline price is broken into a per-day figure
    /// with the real billed price shown as fine print underneath, instead of the billed price up top.
    var showDailyPricing: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            PaywallSubscriptionOptionCard(
                title: String(localized: "paywall.plan_weekly"),
                subtitle: weeklySubtitle,
                primaryPrice: showDailyPricing
                    ? subscriptionManager.weeklyPlanDailyPriceText
                    : subscriptionManager.weeklyPlanWeeklyPriceText,
                secondaryPrice: showDailyPricing ? billedNote(for: .weekly) : nil,
                selected: selection == .weekly,
                badgeText: weeklyBadgeText,
                action: {
                    select(.weekly)
                }
            )

            PaywallSubscriptionOptionCard(
                title: String(localized: "paywall.plan_yearly"),
                subtitle: String(localized: "paywall.cancel_anytime"),
                primaryPrice: showDailyPricing
                    ? subscriptionManager.yearlyPlanDailyPriceText
                    : subscriptionManager.yearlyPlanBilledPriceText,
                secondaryPrice: showDailyPricing ? billedNote(for: .yearly) : nil,
                selected: selection == .yearly,
                badgeText: String(localized: "paywall.badge_best_value"),
                action: {
                    select(.yearly)
                }
            )
        }
    }

    private var weeklyBadgeText: String {
        if subscriptionManager.isEligibleForTrial {
            return String(localized: "paywall.badge_free_trial")
        }
        return String(localized: "paywall.badge_most_popular")
    }

    private var weeklySubtitle: String {
        let price = showDailyPricing
            ? subscriptionManager.weeklyPlanDailyPriceText
            : subscriptionManager.weeklyPlanWeeklyPriceText
        if subscriptionManager.isEligibleForTrial {
            return LocalizationService.shared.localizedFormat("paywall.weekly_subtitle_trial", price)
        }
        return String(localized: "paywall.cancel_anytime")
    }

    /// Real recurring billed price shown as fine print under the daily figure (App Store 3.1.2(c) clarity).
    private func billedNote(for plan: SubscriptionManager.SubscriptionPlan) -> String {
        LocalizationService.shared.localizedFormat(
            "paywall.billed_price_format",
            subscriptionManager.billedPriceText(for: plan)
        )
    }

    private func select(_ newSelection: PaywallSelection) {
        HapticsManager.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
            selection = newSelection
        }
        onSelectionChanged(newSelection)
    }
}

// MARK: - Benefits list ("Unlock full access" bullet points)

struct PaywallBenefitsList: View {
    private let benefitKeys = [
        "paywall.benefit_all_packs",
        "paywall.benefit_ai_packs",
        "paywall.benefit_no_ads"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(benefitKeys, id: \.self) { key in
                Text(LocalizedStringKey(key))
                    .font(.antropicSerif(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Copy helpers

@MainActor
enum PaywallCopy {
    static func ctaTitleKey(selection: PaywallSelection, isEligibleForTrial: Bool) -> String {
        if selection == .weekly && isEligibleForTrial {
            return "category_paywall.cta_trial"
        }
        return "paywall.continue"
    }

    static func subscriptionPlan(for selection: PaywallSelection) -> SubscriptionManager.SubscriptionPlan {
        switch selection {
        case .weekly:
            return .weekly
        case .yearly:
            return .yearly
        }
    }

    static func trialEnabled(selection: PaywallSelection, isEligibleForTrial: Bool) -> Bool {
        selection == .weekly && isEligibleForTrial
    }

    static func analyticsPlanName(for selection: PaywallSelection) -> String {
        switch selection {
        case .weekly:
            return "weekly"
        case .yearly:
            return "yearly"
        }
    }
}
