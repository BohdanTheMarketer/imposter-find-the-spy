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

// MARK: - Player profiles (bundled portraits: player_0 … player_11)

enum PlayerProfiles {
    static let count = 12

    static func slot(for avatarIndex: Int) -> Int {
        let m = avatarIndex % count
        return m >= 0 ? m : m + count
    }

    /// Bundle resource name (no extension) for `Image(_:)`.
    static func bundleImageName(for avatarIndex: Int) -> String {
        "player_\(slot(for: avatarIndex))"
    }

    /// Role-reveal cover portraits: `VV1` … `VV12` align with avatar slots 0 … 11 (same order as `player_0` … `player_11`).
    static func roleRevealPortraitName(for avatarIndex: Int) -> String {
        "VV\(slot(for: avatarIndex) + 1)"
    }

    /// Loads bundled portrait for role-reveal: prefers `VV*` art, then `player_*` (same slot order).
    static func roleRevealUIImage(for avatarIndex: Int) -> UIImage? {
        if let vv = loadBundledImage(named: roleRevealPortraitName(for: avatarIndex)) {
            return vv
        }
        return loadBundledImage(named: bundleImageName(for: avatarIndex))
    }

    /// Loads avatar image by basename across common image extensions.
    /// This is resilient when project resources were renamed (e.g. png -> jpg).
    static func loadBundledImage(named baseName: String) -> UIImage? {
        if let image = UIImage(named: baseName) {
            return image
        }
        for ext in ["jpg", "jpeg", "png"] {
            if let url = Bundle.main.url(forResource: baseName, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}

// MARK: - Avatar theme colors (one per bundled portrait, aligned with player_N.png order)

enum AvatarColors {
    private static let colors: [Color] = [
        Color(red: 0.518, green: 0.800, blue: 0.086), // #84CC16 lime
        Color(red: 1.0, green: 0.624, blue: 0.110), // #FF9F1C orange
        Color(red: 0.169, green: 0.612, blue: 0.922), // #2B9CEB sky blue
        Color(red: 0.576, green: 0.200, blue: 0.918), // #9333EA purple
        Color(red: 0.831, green: 0.396, blue: 0.180), // #D4652E terracotta
        Color(red: 0.427, green: 0.706, blue: 0.949), // #6DB4F2 light blue
        Color(red: 0.239, green: 0.678, blue: 0.961), // #3DADF5 bright sky
        Color(red: 1.0, green: 0.420, blue: 0.208), // #FF6B35 coral orange
        Color(red: 1.0, green: 0.573, blue: 0.220), // #FF9238 warm orange
        Color(red: 0.925, green: 0.282, blue: 0.600), // #EC4899 pink
        Color(red: 0.518, green: 0.878, blue: 0.310), // #84E04F fresh green
        Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E green
    ]

    static func color(for avatarIndex: Int) -> Color {
        colors[PlayerProfiles.slot(for: avatarIndex)]
    }
}

// MARK: - Avatar thumbnails (mini profile icons)

struct PlayerAvatarThumbnailView: View {
    let avatarIndex: Int
    var size: CGFloat = 44
    /// Use `size / 2` for a circle.
    var cornerRadius: CGFloat

    @State private var backdropColor: Color?

    private var fillColor: Color {
        backdropColor ?? AvatarColors.color(for: avatarIndex)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
                if let ui = PlayerProfiles.loadBundledImage(named: PlayerProfiles.bundleImageName(for: avatarIndex)) {
                    Image(uiImage: ui)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear { refreshBackdrop() }
        .onChange(of: avatarIndex) { _ in
            refreshBackdrop()
        }
    }

    private func refreshBackdrop() {
        let name = PlayerProfiles.bundleImageName(for: avatarIndex)
        if let ui = PlayerProfiles.loadBundledImage(named: name) {
            backdropColor = ui.portraitBackdropColor()
        } else {
            backdropColor = nil
        }
    }
}

/// Square tile for voting grid; pair with `aspectRatio(1, contentMode: .fit)` on the parent.
struct PlayerAvatarSquareTileView: View {
    let avatarIndex: Int
    var cornerRadius: CGFloat = 16

    @State private var backdropColor: Color?

    private var fillColor: Color {
        backdropColor ?? AvatarColors.color(for: avatarIndex)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
                if let ui = PlayerProfiles.loadBundledImage(named: PlayerProfiles.bundleImageName(for: avatarIndex)) {
                    Image(uiImage: ui)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .onAppear {
            let name = PlayerProfiles.bundleImageName(for: avatarIndex)
            if let ui = PlayerProfiles.loadBundledImage(named: name) {
                backdropColor = ui.portraitBackdropColor()
            }
        }
    }
}

// MARK: - Previews

#Preview("Avatar thumbnails (all 12)") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Circle (setup row)")
                .font(.headline)
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                ForEach(0 ..< PlayerProfiles.count, id: \.self) { i in
                    VStack(spacing: 6) {
                        PlayerAvatarThumbnailView(avatarIndex: i, size: 52, cornerRadius: 26)
                        Text("\(i)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            Text("Square tile (voting)")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top, 8)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0 ..< PlayerProfiles.count, id: \.self) { i in
                    PlayerAvatarSquareTileView(avatarIndex: i)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding()
    }
    .background(Color(red: 0.08, green: 0.08, blue: 0.1))
}
