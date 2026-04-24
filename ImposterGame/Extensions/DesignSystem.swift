import SwiftUI
import UIKit
import CoreText

// MARK: - Colors
extension Color {
    // Claude Design system tokens (mapped to SwiftUI)
    static let appBackground = Color(red: 0.055, green: 0.043, blue: 0.122) // #0E0B1F
    static let appBackgroundElevated = Color(red: 0.082, green: 0.071, blue: 0.165) // #15122A
    static let appAccent = Color(red: 1.0, green: 0.063, blue: 0.620) // #FF109E
    static let appAccentHigh = Color(red: 1.0, green: 0.345, blue: 0.745) // #FF58BE
    static let appTextOnAccent = Color.white
    static let appSurface = Color(red: 0.102, green: 0.090, blue: 0.188) // #1A1730
    static let appSurface2 = Color(red: 0.141, green: 0.125, blue: 0.239) // #24203D
    static let appCardBackground = Color.appSurface

    // Gradient colors from reference images
    static let gradientRedTop = Color(red: 1.0, green: 0.25, blue: 0.3)
    static let gradientRedBottom = Color(red: 0.9, green: 0.1, blue: 0.2)
    static let gradientPinkTop = Color(red: 1.0, green: 0.2, blue: 0.35)
    static let gradientPinkBottom = Color(red: 0.85, green: 0.05, blue: 0.15)

    // Screen-specific backgrounds
    static let onboardingGreen = Color(red: 0.35, green: 0.78, blue: 0.4)
    static let onboardingRed = Color(red: 0.95, green: 0.3, blue: 0.35)
    static let onboardingBlue = Color(red: 0.3, green: 0.7, blue: 0.95)
    static let paywallPurpleTop = Color(red: 0.478, green: 0.298, blue: 1.0) // #7A4CFF
    static let paywallPurple = Color(red: 0.357, green: 0.169, blue: 0.878) // #5B2BE0
    static let paywallPurpleDeep = Color(red: 0.243, green: 0.090, blue: 0.710) // #3E17B5

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
    static let gameplayBackgroundTop = Color.appBackground
    static let gameplayBackgroundBottom = Color.appBackgroundElevated
    static let gameplayTitle = Color.white
    static let gameplaySurface = Color.appSurface
    static let gameplayButtonPrimary = Color.appAccent
    static let gameplayButtonSecondary = Color.appSurface2
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
        colors: [Color.paywallPurpleTop, Color.paywallPurple, Color.paywallPurpleDeep],
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
            .foregroundColor(.appTextOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.appAccent.opacity(0.45), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GameplayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.evolventa(size: 18, weight: .bold))
            .foregroundColor(.appTextOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.gameplayButtonPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.appAccent.opacity(0.45), radius: 12, x: 0, y: 6)
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

// MARK: - App fonts (design-system aligned sans typography)

extension Font {
    /// Legacy app font helper now mapped to the app sans family.
    static func evolventa(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        appSans(size: size, weight: weight)
    }

    /// Kept for compatibility; app-wide typography uses app sans.
    static func antropicSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        appSans(size: size, weight: weight)
    }

    /// Kept for compatibility; app-wide typography uses app sans.
    static func antropicSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        appSans(size: size, weight: weight)
    }

    /// Kept for backward compatibility with previous name.
    static func nanumMyeongjo(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        appSans(size: size, weight: weight)
    }

    /// Primary app font family (Inter if available, otherwise system sans).
    static func appSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let candidates: [String]
        switch weight {
        case .black, .heavy, .bold:
            candidates = ["Inter-Bold", "Inter-SemiBold", "SFProDisplay-Bold"]
        case .semibold:
            candidates = ["Inter-SemiBold", "Inter-Medium", "SFProText-Semibold"]
        case .medium:
            candidates = ["Inter-Medium", "Inter-Regular", "SFProText-Medium"]
        default:
            candidates = ["Inter-Regular", "Inter", "SFProText-Regular"]
        }
        return customFontFromCandidates(candidates, size: size, fallbackWeight: weight)
    }

    private static func customFontFromCandidates(
        _ postScriptCandidates: [String],
        size: CGFloat,
        fallbackWeight: Font.Weight
    ) -> Font {
        for name in postScriptCandidates where AppFontRegistrar.isFontAvailable(name: name, size: size) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: fallbackWeight)
    }
}

enum AppFontRegistrar {
    private static let libreFontFiles = [
        "LibreBaskerville-Regular",
        "LibreBaskerville-Medium",
        "LibreBaskerville-SemiBold",
        "LibreBaskerville-Bold",
        "LibreBaskerville-Italic",
        "LibreBaskerville-MediumItalic",
        "LibreBaskerville-SemiBoldItalic",
        "LibreBaskerville-BoldItalic"
    ]

    private static let searchSubdirectories: [String?] = [nil, "Fonts", "Resources/Fonts"]

    static func registerAppFonts() {
        for fileBaseName in libreFontFiles {
            guard let url = fontURL(baseName: fileBaseName) else { continue }
            guard let provider = CGDataProvider(url: url as CFURL),
                  let cgFont = CGFont(provider)
            else { continue }

            var error: Unmanaged<CFError>?
            CTFontManagerRegisterGraphicsFont(cgFont, &error)
            // Ignore "already registered" errors; availability check below handles final state.
            _ = error
        }
    }

    static func isFontAvailable(name: String, size: CGFloat) -> Bool {
        UIFont(name: name, size: size) != nil
    }

    private static func fontURL(baseName: String) -> URL? {
        for subdirectory in searchSubdirectories {
            if let url = Bundle.main.url(forResource: baseName, withExtension: "ttf", subdirectory: subdirectory) {
                return url
            }
        }
        return nil
    }
}

// MARK: - Player profiles (bundled portraits: `player_1` … `player_12`, thumbnails: `small_player_1` … `small_player_12`)

enum PlayerProfiles {
    static let count = 12

    static func slot(for avatarIndex: Int) -> Int {
        let m = avatarIndex % count
        return m >= 0 ? m : m + count
    }

    /// Full-screen portrait for role reveal (`player_1` … `player_12`).
    static func fullPortraitBaseName(for avatarIndex: Int) -> String {
        "player_\(slot(for: avatarIndex) + 1)"
    }

    /// Small circular asset for lists (`small_player_1` … `small_player_12`).
    static func thumbnailBaseName(for avatarIndex: Int) -> String {
        "small_player_\(slot(for: avatarIndex) + 1)"
    }

    /// Legacy alias: full portrait basename.
    static func bundleImageName(for avatarIndex: Int) -> String {
        fullPortraitBaseName(for: avatarIndex)
    }

    /// Loads the large reveal portrait.
    static func roleRevealUIImage(for avatarIndex: Int) -> UIImage? {
        loadBundledImage(named: fullPortraitBaseName(for: avatarIndex))
    }

    /// Loads avatar image by basename across common image extensions.
    static func loadBundledImage(named baseName: String) -> UIImage? {
        if let image = UIImage(named: baseName) {
            return image
        }
        let searchSubdirectories: [String?] = [
            nil,
            "Onboarding",
            "Resources/Onboarding",
            "PlayerAvatars",
            "Resources/PlayerAvatars"
        ]
        for ext in ["png", "jpg", "jpeg"] {
            for subdirectory in searchSubdirectories {
                if let url = Bundle.main.url(
                    forResource: baseName,
                    withExtension: ext,
                    subdirectory: subdirectory
                ), let image = UIImage(contentsOfFile: url.path) {
                    return image
                }
            }
        }
        // Last-resort lookup: scan bundle contents in case Xcode nests resources unexpectedly.
        if let resourceURL = Bundle.main.resourceURL,
           let enumerator = FileManager.default.enumerator(
               at: resourceURL,
               includingPropertiesForKeys: nil,
               options: [.skipsHiddenFiles]
           ) {
            let validExtensions = Set(["png", "jpg", "jpeg"])
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                guard validExtensions.contains(ext) else { continue }
                guard fileURL.deletingPathExtension().lastPathComponent == baseName else { continue }
                if let image = UIImage(contentsOfFile: fileURL.path) {
                    return image
                }
            }
        }
        return nil
    }
}

// MARK: - Avatar theme colors (aligned with `player_1` … `player_12` for slots 0 … 11)

enum AvatarColors {
    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    private static let colors: [Color] = [
        rgb(242, 145, 4), // player_1  #f29104
        rgb(74, 141, 219), // player_2  #4a8ddb
        rgb(199, 64, 12), // player_3  #c7400c
        rgb(238, 145, 12), // player_4  #ee910c
        rgb(198, 67, 14), // player_5  #c6430e
        rgb(77, 161, 29), // player_6  #4da11d
        rgb(74, 160, 27), // player_7  #4aa01b
        rgb(202, 65, 10), // player_8  #ca410a
        rgb(74, 141, 219), // player_9  #4a8ddb
        rgb(242, 145, 8), // player_10 #f29108
        rgb(79, 141, 221), // player_11 #4f8ddd
        rgb(73, 160, 27) // player_12 #49a01b
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

    private var fillColor: Color {
        AvatarColors.color(for: avatarIndex)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
                if let ui = PlayerProfiles.loadBundledImage(named: PlayerProfiles.thumbnailBaseName(for: avatarIndex)) {
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
    }
}

/// Square tile for voting grid; pair with `aspectRatio(1, contentMode: .fit)` on the parent.
struct PlayerAvatarSquareTileView: View {
    let avatarIndex: Int
    var cornerRadius: CGFloat = 16

    private var fillColor: Color {
        AvatarColors.color(for: avatarIndex)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
                if let ui = PlayerProfiles.loadBundledImage(named: PlayerProfiles.thumbnailBaseName(for: avatarIndex)) {
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
