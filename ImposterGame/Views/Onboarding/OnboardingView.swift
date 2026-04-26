import SwiftUI
import UIKit

struct OnboardingPage {
    let imageName: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let buttonTitle: String
}

struct OnboardingView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var currentPage = 0

    /// Pages after the Stitch hero (glass & grid style from DESIGN.md).
    private let followPages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "OnboardingScreen2",
            title: "Instant Fun\nAnywhere!",
            subtitle: "Game night, road trip, or\neven an awkward first meeting —\nFakeit breaks the ice and\nbrings the fun",
            backgroundColor: Color.pastelOrangeOnboarding,
            buttonTitle: "I'm In!"
        ),
        OnboardingPage(
            imageName: "OnboardingScreen3",
            title: "Who's Faking It?",
            subtitle: "One of you is lying.\nThe rest know the word.\nCan you spot the imposter\nbefore it's too late?",
            backgroundColor: Color.pastelGreenOnboarding,
            buttonTitle: "Got It"
        )
    ]

    private var totalPages: Int { 1 + followPages.count }

    var body: some View {
        ZStack {
            Group {
                if currentPage == 0 {
                    stitchFirstOnboardingPage
                } else if currentPage - 1 < followPages.count {
                    classicOnboardingPage(followPages[currentPage - 1])
                } else {
                    stitchFirstOnboardingPage
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: currentPage)
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Stitch first screen (blueprint / 3D hero)

    private var stitchFirstOnboardingPage: some View {
        ZStack {
            Color.pastelYellowOnboarding
            .ignoresSafeArea()

            BlueprintGridOverlay(lineColor: Color.black.opacity(0.1), spacing: 28)

            // Floating technical sketches
            BlueprintSketchOverlay()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    onboardingImage("OnboardingScreen1")
                        .frame(maxWidth: min(geo.size.width * 0.88, 360))
                        .frame(height: geo.size.height * 0.5)
                        .padding(.top, 16)

                    Text("Talk Smarter")
                        .font(.evolventa(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .multilineTextAlignment(.center)

                    Text("Guess Better")
                        .font(.evolventa(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 14)

                    Text("Describe the secret word without saying it.\nBut beware — the imposter is listening and trying to blend in")
                        .font(.evolventa(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 28)

                    Spacer(minLength: 8)

                    // Primary CTA — deep onyx + electric purple glow (DESIGN.md)
                    Button(action: { advanceFromOnboarding() }) {
                        Text("Let's Play!")
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Color.stitchDeepOnyx)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.stitchElectricPurple.opacity(0.95), lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 12, y: 4)
                            .shadow(color: Color.black.opacity(0.1), radius: 22, y: 0)
                    }
                    .buttonStyle(OnboardingSquishButtonStyle())
                    .padding(.horizontal, 36)
                    .padding(.bottom, 44)
                }
            }
        }
    }

    // MARK: - Classic follow-up pages

    @ViewBuilder
    private func classicOnboardingPage(_ page: OnboardingPage) -> some View {
        ZStack {
            page.backgroundColor
                .ignoresSafeArea()
                .overlay(
                    GridPatternView(lineColor: .white.opacity(0.35))
                        .opacity(0.15)
                )

            GeometryReader { geo in
                VStack(spacing: 0) {
                    onboardingImage(page.imageName)
                        .frame(maxWidth: min(geo.size.width * 0.88, 360))
                        .frame(height: geo.size.height * 0.5)
                        .padding(.top, 16)

                    Text(page.title)
                        .font(.evolventa(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)

                    Text(page.subtitle)
                        .font(.evolventa(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)

                    Spacer(minLength: 8)

                    Button(action: { advanceFromOnboarding() }) {
                        Text(page.buttonTitle)
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.stitchDeepOnyx)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.stitchElectricPurple.opacity(0.7), lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 2)
                            .shadow(color: Color.black.opacity(0.1), radius: 16, y: 0)
                    }
                    .buttonStyle(OnboardingSquishButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            }
        }
    }

    @ViewBuilder
    private func onboardingImage(_ imageName: String) -> some View {
        if let uiImage = UIImage(named: imageName) {
            Image(uiImage: uiImage.removingBlackBackgroundFromEdges(cacheKey: imageName) ?? uiImage)
                .resizable()
                .scaledToFit()
                .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
        } else {
            Image(systemName: "photo")
                .font(.system(size: 88, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func advanceFromOnboarding() {
        HapticsManager.impact(.light)
        if currentPage < totalPages - 1 {
            currentPage += 1
        } else {
            subscriptionManager.hasCompletedOnboarding = true
            let next = subscriptionManager.isPremium ? "player_setup" : "paywall"
            AnalyticsService.logEvent("onboarding_complete", parameters: ["next": next])
            if subscriptionManager.isPremium {
                router.navigate(to: .playerSetup)
            } else {
                router.navigate(to: .paywall)
            }
        }
    }

}

// MARK: - Blueprint grid (purple graph paper)

struct GridPatternView: View {
    var lineColor: Color = .white.opacity(0.3)

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
    }
}

private struct BlueprintGridOverlay: View {
    var lineColor: Color
    var spacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Decorative blueprint sketches

private struct BlueprintSketchOverlay: View {
    var body: some View {
        Canvas { context, size in
            let faint = Color.stitchElectricPurple.opacity(0.12)
            let strokeStyle = StrokeStyle(lineWidth: 1, dash: [6, 5])

            // Circles
            for i in 0..<4 {
                let r = CGFloat(40 + i * 55)
                let rect = CGRect(
                    x: size.width * 0.65 - r * 0.5,
                    y: CGFloat(80 + i * 22),
                    width: r,
                    height: r
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(faint),
                    style: strokeStyle
                )
            }

            // Cross-hatched rectangle
            var rectPath = Path()
            rectPath.addRoundedRect(
                in: CGRect(x: size.width * 0.06, y: size.height * 0.18, width: 72, height: 56),
                cornerSize: CGSize(width: 8, height: 8)
            )
            context.stroke(rectPath, with: .color(faint), lineWidth: 1)

            // Diagonal hatch
            for o in stride(from: -40, through: 80, by: 14) {
                var h = Path()
                h.move(to: CGPoint(x: size.width * 0.06 + CGFloat(o), y: size.height * 0.18))
                h.addLine(to: CGPoint(x: size.width * 0.06 + CGFloat(o) + 40, y: size.height * 0.18 + 56))
                context.stroke(h, with: .color(faint.opacity(0.8)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Interaction

private struct OnboardingSquishButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension Color {
    fileprivate static let pastelYellowOnboarding = Color(red: 1.0, green: 0.84, blue: 0.25)
    fileprivate static let pastelOrangeOnboarding = Color(red: 1.0, green: 0.58, blue: 0.32)
    fileprivate static let pastelGreenOnboarding = Color(red: 0.35, green: 0.78, blue: 0.34)
}

private extension UIImage {
    private static let transparentBgCache = NSCache<NSString, UIImage>()

    func removingBlackBackgroundFromEdges(cacheKey: String) -> UIImage? {
        if let cached = Self.transparentBgCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        guard let sourceCG = cgImage else { return nil }

        let width = sourceCG.width
        let height = sourceCG.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height
        var pixels = [UInt8](repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(sourceCG, in: CGRect(x: 0, y: 0, width: width, height: height))

        func offset(_ x: Int, _ y: Int) -> Int {
            (y * width + x) * bytesPerPixel
        }

        func isNearBlack(_ i: Int) -> Bool {
            let r = Int(pixels[i])
            let g = Int(pixels[i + 1])
            let b = Int(pixels[i + 2])
            let a = Int(pixels[i + 3])
            return a > 0 && r <= 26 && g <= 26 && b <= 26
        }

        var visited = [Bool](repeating: false, count: width * height)
        var queue: [(Int, Int)] = []
        queue.reserveCapacity((width + height) * 2)

        func enqueueIfBackground(_ x: Int, _ y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            let idx = y * width + x
            guard !visited[idx] else { return }
            let p = offset(x, y)
            guard isNearBlack(p) else { return }
            visited[idx] = true
            queue.append((x, y))
        }

        for x in 0..<width {
            enqueueIfBackground(x, 0)
            enqueueIfBackground(x, height - 1)
        }
        for y in 0..<height {
            enqueueIfBackground(0, y)
            enqueueIfBackground(width - 1, y)
        }

        var qIndex = 0
        while qIndex < queue.count {
            let (x, y) = queue[qIndex]
            qIndex += 1

            let p = offset(x, y)
            pixels[p + 3] = 0

            enqueueIfBackground(x + 1, y)
            enqueueIfBackground(x - 1, y)
            enqueueIfBackground(x, y + 1)
            enqueueIfBackground(x, y - 1)
        }

        guard let output = context.makeImage() else { return nil }
        let result = UIImage(cgImage: output, scale: scale, orientation: imageOrientation)
        Self.transparentBgCache.setObject(result, forKey: cacheKey as NSString)
        return result
    }
}
