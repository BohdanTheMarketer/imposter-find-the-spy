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

    var body: some View {
        Button(action: action) {
            HStack {
                Text(LocalizedStringKey(titleKey))
                    .font(.antropicSerif(size: 19, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.antropicSerif(size: 19, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
            }
            .padding(.horizontal, 22)
            .frame(height: 60)
            .background(Color.appAccent)
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

// MARK: - Copy helpers

@MainActor
enum PaywallCopy {
    static func ctaBilledLine(
        subscriptionManager: SubscriptionManager,
        plan: SubscriptionManager.SubscriptionPlan
    ) -> String {
        subscriptionManager.billedPriceText(for: plan)
    }

    static func ctaSubordinateLineKey(showsTrialPitch: Bool) -> String {
        showsTrialPitch ? "paywall.cta.start_trial" : "paywall.continue"
    }

    /// Guideline 3.1.2(c): weekly CTA always shows billed amount on line 2.
    static func usesDualLineCTA(selectedPlanIsWeekly: Bool) -> Bool {
        selectedPlanIsWeekly
    }
}
