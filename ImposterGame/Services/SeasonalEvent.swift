import Foundation

/// Time-boxed, optionally region-gated word pack (Halloween, Christmas, ...). The single place
/// to switch an event on or off: the pack shows only inside `start..<end` and only for device
/// regions in `regions`, so it disappears on its own after `end` without a new release.
///
/// Cleanup once an event is over: drop it from `all`, delete `WordPacks/*/<slug>.json`, its
/// colors in DesignSystem.swift (`// MARK: - Seasonal`) and its strings.
struct SeasonalEvent {
    /// Word-pack file name (`WordPacks/<locale>/<slug>.json`) and the analytics identifier.
    let slug: String
    /// Inclusive, UTC.
    let start: Date
    /// Exclusive, UTC.
    let end: Date
    /// ISO 3166-1 alpha-2 device regions that see the event. `nil` = every region.
    let regions: Set<String>?
    /// Shown on the imposter's role card while this pack is played, instead of the spy.
    let imposterEmoji: String

    static let halloween2026 = SeasonalEvent(
        slug: "halloween",
        start: utcDate(2026, 10, 20),
        end: utcDate(2026, 11, 3), // keeps Día de Muertos (Nov 1–2) for MX
        regions: ["US", "CA", "GB", "IE", "AU", "NZ", "MX", "BR"],
        imposterEmoji: "🎃"
    )

    /// Every event the app knows about; active ones are pinned above the regular packs, in this order.
    static let all: [SeasonalEvent] = [.halloween2026]

    static var active: [SeasonalEvent] {
        all.filter { $0.isActive() }
    }

    static func event(slug: String?) -> SeasonalEvent? {
        guard let slug else { return nil }
        return all.first { $0.slug == slug }
    }

    func isActive() -> Bool {
        Self.qaOverride ?? isScheduled()
    }

    /// Real schedule and region check, ignoring the QA override.
    func isScheduled(now: Date = Date(), region: String? = Locale.current.region?.identifier) -> Bool {
        guard now >= start, now < end else { return false }
        guard let regions else { return true }
        guard let region else { return false }
        return regions.contains(region)
    }

    /// Reports whether this device would see any event right now, independent of the QA override,
    /// so Amplitude can compare eligible vs non-eligible regions during the event window.
    static func reportEligibility() {
        let eligible = all.contains { $0.isScheduled() }
        AnalyticsService.setUserProperty(eligible ? "true" : "false", for: "seasonal_event_eligible")
    }

    // MARK: - QA

    private static let qaOverrideKey = "com.imposter.seasonalEvent.qaOverride"

    /// Wired to the `admin_event_on` / `admin_event_off` / `admin_event_auto` commands in
    /// `PlayerOptionsSheet` (PlayerSetupView.swift). Forces every event on or off regardless of
    /// dates and region; `nil` returns to the real schedule. Works in TestFlight/Release builds.
    static var qaOverride: Bool? {
        get { UserDefaults.standard.object(forKey: qaOverrideKey) as? Bool }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: qaOverrideKey)
            } else {
                UserDefaults.standard.removeObject(forKey: qaOverrideKey)
            }
        }
    }

    static var qaDiagnosticSummary: String {
        let override = qaOverride.map { $0 ? "ON" : "OFF" } ?? "auto"
        return """
        seasonalEventOverride = \(override)
        deviceRegion = \(Locale.current.region?.identifier ?? "nil")
        activeEvents = \(active.map(\.slug).joined(separator: ","))
        """
    }

    private static func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantFuture
    }
}
