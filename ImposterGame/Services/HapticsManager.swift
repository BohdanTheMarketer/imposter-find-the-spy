import UIKit

enum HapticsManager {
    private static let hapticsEnabledKey = "hapticsEnabled"

    /// When `false`, impact/notification/selection calls are no-ops (Vibration setting off).
    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: hapticsEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: hapticsEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hapticsEnabledKey) }
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
