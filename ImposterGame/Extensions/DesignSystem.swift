import SwiftUI
import UIKit

// MARK: - Colors
extension Color {
    static let appBackground = Color(red: 0.1, green: 0.02, blue: 0.2)
    static let appAccent = Color(red: 0.486, green: 0.227, blue: 0.929) // #7C3AED
    static let appSurface = Color(red: 0.176, green: 0.106, blue: 0.306) // #2D1B4E
    static let appCardBackground = Color(red: 0.15, green: 0.1, blue: 0.25)

    // Gradient colors from reference images
    static let gradientRedTop = Color(red: 1.0, green: 0.25, blue: 0.3)
    static let gradientRedBottom = Color(red: 0.9, green: 0.1, blue: 0.2)
    static let gradientPinkTop = Color(red: 1.0, green: 0.2, blue: 0.35)
    static let gradientPinkBottom = Color(red: 0.85, green: 0.05, blue: 0.15)

    // Screen-specific backgrounds
    static let onboardingGreen = Color(red: 0.35, green: 0.78, blue: 0.4)
    static let onboardingRed = Color(red: 0.95, green: 0.3, blue: 0.35)
    static let onboardingBlue = Color(red: 0.3, green: 0.7, blue: 0.95)
    static let paywallPurple = Color(red: 0.45, green: 0.2, blue: 0.85)

    // Stitch design guide (DESIGN.md) — onboarding / premium energy
    /// Electric Purple #8B44FF
    static let stitchElectricPurple = Color(red: 0.545, green: 0.267, blue: 1.0)
    /// Deep Onyx #1A1A1A — primary buttons
    static let stitchDeepOnyx = Color(red: 0.102, green: 0.102, blue: 0.102)
    /// Dark stage background (navy / purple night)
    static let stitchNightBase = Color(red: 0.07, green: 0.05, blue: 0.14)

    // Role reveal colors
    static let revealOrange = Color(red: 1.0, green: 0.65, blue: 0.0)
    static let revealGreen = Color(red: 0.3, green: 0.8, blue: 0.35)
    static let revealBlue = Color(red: 0.3, green: 0.55, blue: 0.95)
    static let revealPurple = Color(red: 0.6, green: 0.3, blue: 0.9)
    static let revealPink = Color(red: 0.95, green: 0.3, blue: 0.5)

    // Core gameplay theme (exclude onboarding/paywall/reveal).
    static let gameplayBackgroundTop = Color(red: 0.05, green: 0.05, blue: 0.14)
    static let gameplayBackgroundBottom = Color(red: 0.02, green: 0.02, blue: 0.10)
    static let gameplayTitle = Color(red: 1.0, green: 0.06, blue: 0.62)
    static let gameplaySurface = Color(red: 0.10, green: 0.10, blue: 0.20)
    static let gameplayButtonPrimary = Color(red: 1.0, green: 0.06, blue: 0.62)
    static let gameplayButtonSecondary = Color(red: 0.13, green: 0.13, blue: 0.22)
}

// MARK: - Gradients
extension LinearGradient {
    static let appRedGradient = LinearGradient(
        colors: [Color.gradientRedTop, Color.gradientRedBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    static let appPinkGradient = LinearGradient(
        colors: [Color.gradientPinkTop, Color.gradientPinkBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    static let appPurpleGradient = LinearGradient(
        colors: [Color.paywallPurple, Color(red: 0.25, green: 0.1, blue: 0.5)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let darkGradient = LinearGradient(
        colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.06, green: 0.06, blue: 0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let gameplayBackground = LinearGradient(
        colors: [Color.gameplayBackgroundTop, Color.gameplayBackgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    var backgroundColor: Color = Color(white: 0.15)

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var backgroundColor: Color = Color(white: 0.12)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.evolventa(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GameplayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.evolventa(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.gameplayButtonPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GameplayRoundIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(Color.gameplayButtonPrimary)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(backgroundColor: Color = Color(white: 0.15)) -> some View {
        modifier(CardStyle(backgroundColor: backgroundColor))
    }

    func gameplayScreenBackground(gridOpacity: Double = 0.10) -> some View {
        background(
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(gridOpacity)
                )
        )
    }
}

// MARK: - Evolventa (bundled TTF; register in Info.plist UIAppFonts)

extension Font {
    /// Evolventa custom font. Bold weights use `Evolventa-Bold`; all others use `Evolventa-Regular`.
    static func evolventa(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let isBold = weight == .semibold
            || weight == .bold
            || weight == .heavy
            || weight == .black
        let postScriptName = isBold ? "Evolventa-Bold" : "Evolventa-Regular"
        // If bundled font files are missing, preserve intended visual hierarchy with weighted system fallback.
        if UIFont(name: postScriptName, size: size) != nil {
            return .custom(postScriptName, size: size)
        }
        return .system(size: size, weight: weight)
    }
}

// MARK: - Avatar Colors
enum AvatarColors {
    static let colors: [Color] = [
        .revealOrange, .revealGreen, .revealBlue, .revealPurple,
        .revealPink, Color.yellow, Color.cyan, Color.mint,
        Color.indigo, Color.teal, Color.brown, Color.orange,
        Color.pink, Color.green, Color.blue
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}

// MARK: - Player Emoji Avatars
enum PlayerAvatars {
    static let avatars = [
        "😎", "🤩", "😈", "🤡", "👻",
        "🦊", "🐸", "🎃", "🤖", "👽",
        "🦁", "🐵", "🐷", "🐼", "🦄"
    ]

    static func avatar(for index: Int) -> String {
        avatars[index % avatars.count]
    }
}
