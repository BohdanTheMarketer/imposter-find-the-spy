import SwiftUI

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

    // Role reveal colors
    static let revealOrange = Color(red: 1.0, green: 0.65, blue: 0.0)
    static let revealGreen = Color(red: 0.3, green: 0.8, blue: 0.35)
    static let revealBlue = Color(red: 0.3, green: 0.55, blue: 0.95)
    static let revealPurple = Color(red: 0.6, green: 0.3, blue: 0.9)
    static let revealPink = Color(red: 0.95, green: 0.3, blue: 0.5)
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
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(backgroundColor: Color = Color(white: 0.15)) -> some View {
        modifier(CardStyle(backgroundColor: backgroundColor))
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
