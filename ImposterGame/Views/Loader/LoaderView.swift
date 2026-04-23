import SwiftUI

// MARK: - Splash colour tokens
private extension Color {
    static let splashRed    = Color(red: 0.902, green: 0.224, blue: 0.275) // #E63946
    static let splashRedMid = Color(red: 0.769, green: 0.118, blue: 0.180) // #C41E2E
    static let splashRedDark = Color(red: 0.545, green: 0.082, blue: 0.129) // #8B1521
    static let splashYellow = Color(red: 1.0,   green: 0.824, blue: 0.247) // #FFD23F
}

// MARK: - Question mark descriptors
private struct QMark {
    let xFrac: CGFloat   // 0…1 of screen width
    let yFrac: CGFloat   // 0…1 of screen height
    let size: CGFloat
    let color: Color
    let rotation: Double // degrees
    let delay: Double    // seconds
}

private let qmarks: [QMark] = [
    QMark(xFrac: 0.12, yFrac: 0.18, size: 54, color: .splashYellow,  rotation: -14, delay: 1.60),
    QMark(xFrac: 0.82, yFrac: 0.14, size: 38, color: .white,         rotation:  18, delay: 1.75),
    QMark(xFrac: 0.08, yFrac: 0.58, size: 44, color: .splashYellow,  rotation:  22, delay: 1.85),
    QMark(xFrac: 0.86, yFrac: 0.62, size: 60, color: .splashYellow,  rotation: -20, delay: 1.70),
    QMark(xFrac: 0.20, yFrac: 0.78, size: 30, color: .white,         rotation:   8, delay: 1.95),
    QMark(xFrac: 0.74, yFrac: 0.82, size: 34, color: .white,         rotation: -10, delay: 2.05),
    QMark(xFrac: 0.48, yFrac: 0.10, size: 28, color: .splashYellow,  rotation:   0, delay: 1.90),
    QMark(xFrac: 0.50, yFrac: 0.92, size: 26, color: .white,         rotation:  14, delay: 2.10),
]

// MARK: - Letter descriptors  "I M P O S T E R ?"
private struct SlamLetter {
    let char: String
    let delay: Double   // seconds from start
    let isQ: Bool
}

private let imposterLetters: [SlamLetter] = [
    SlamLetter(char: "I", delay: 1.800, isQ: false),
    SlamLetter(char: "M", delay: 1.840, isQ: false),
    SlamLetter(char: "P", delay: 1.880, isQ: false),
    SlamLetter(char: "O", delay: 1.920, isQ: false),
    SlamLetter(char: "S", delay: 1.960, isQ: false),
    SlamLetter(char: "T", delay: 2.000, isQ: false),
    SlamLetter(char: "E", delay: 2.040, isQ: false),
    SlamLetter(char: "R", delay: 2.080, isQ: false),
    SlamLetter(char: "?", delay: 2.160, isQ: true),
]

// MARK: - LoaderView

struct LoaderView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    /// Prevents re-running navigation when NavigationPath briefly resets.
    private static var didScheduleInitialNavigation = false

    // Background
    @State private var bgScale: CGFloat = 1.15

    // Grid
    @State private var gridOpacity: Double = 0.0

    // Spotlight
    @State private var spotlightOffsetX: CGFloat = -0.5
    @State private var spotlightOffsetY: CGFloat = -0.3
    @State private var spotlightOpacity: Double = 0.0
    @State private var spotlightScale: CGFloat = 0.8

    // "WHO'S" / "THE"
    @State private var whosOffset: CGFloat = -30
    @State private var whosOpacity: Double = 0
    @State private var theOffset: CGFloat = -30
    @State private var theOpacity: Double = 0

    // Logo
    @State private var logoScale: CGFloat = 0.2
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -18
    @State private var logoBreathing: CGFloat = 1.0
    @State private var logoShineX: CGFloat = -1.5

    // Decorative rings
    @State private var ring1Scale: CGFloat = 0.9
    @State private var ring1Opacity: Double = 0
    @State private var ring2Scale: CGFloat = 0.9
    @State private var ring2Opacity: Double = 0

    // Logo drop shadow ellipse
    @State private var shadowScaleX: CGFloat = 0.3
    @State private var shadowOpacity: Double = 0

    // Scanning beam
    @State private var beamOffsetX: CGFloat = -0.6
    @State private var beamOpacity: Double = 0

    // Question marks  (opacity + Y offset per mark)
    @State private var qmarkOpacities: [Double] = Array(repeating: 0, count: qmarks.count)
    @State private var qmarkOffsets: [CGFloat] = Array(repeating: 30, count: qmarks.count)

    // "IMPOSTER?" letter slam
    @State private var letterOpacities: [Double] = Array(repeating: 0, count: imposterLetters.count)
    @State private var letterOffsets: [CGFloat] = Array(repeating: -40, count: imposterLetters.count)
    @State private var letterScales: [CGFloat] = Array(repeating: 0.3, count: imposterLetters.count)

    // Yellow slash
    @State private var slashWidth: CGFloat = 0

    // Bottom tagline
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 12

    // Loading dots
    @State private var dotsOpacity: Double = 0
    @State private var dotOffsets: [CGFloat] = [0, 0, 0]

    // Final white wipe
    @State private var wipeScale: CGFloat = 0

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                splashBackground(geo: geo)
                gridLayer
                vignetteLayer
                spotlightLayer(geo: geo)
                beamLayer(geo: geo)
                questionMarksLayer(geo: geo)
                whoSTheLabel(geo: geo)
                logoStack(geo: geo)
                headlineBlock(geo: geo)
                bottomTagline(geo: geo)
                loadingDots(geo: geo)
                wipeOverlay(geo: geo)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .onAppear { triggerAnimation() }
    }

    // MARK: - Layer builders

    private func splashBackground(geo: GeometryProxy) -> some View {
        RadialGradient(
            colors: [.splashRed, .splashRedMid, .splashRedDark],
            center: UnitPoint(x: 0.5, y: 0.45),
            startRadius: 0,
            endRadius: geo.size.height * 0.8
        )
        .scaleEffect(bgScale)
        .ignoresSafeArea()
    }

    private var gridLayer: some View {
        GridPatternView(lineColor: .white.opacity(0.08))
            .opacity(gridOpacity)
            .ignoresSafeArea()
    }

    private var vignetteLayer: some View {
        RadialGradient(
            colors: [.clear, Color.black.opacity(0.55)],
            center: .center,
            startRadius: 0,
            endRadius: 500
        )
        .ignoresSafeArea()
    }

    private func spotlightLayer(geo: GeometryProxy) -> some View {
        RadialGradient(
            colors: [Color.white.opacity(0.22), .clear],
            center: .center,
            startRadius: 0,
            endRadius: geo.size.width * 0.55
        )
        .frame(width: geo.size.width * 1.6, height: geo.size.height * 1.6)
        .offset(
            x: spotlightOffsetX * geo.size.width,
            y: spotlightOffsetY * geo.size.height
        )
        .scaleEffect(spotlightScale)
        .opacity(spotlightOpacity)
    }

    private func beamLayer(geo: GeometryProxy) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: geo.size.width * 0.4, height: geo.size.height)
            .rotationEffect(.degrees(-18))
            .offset(x: beamOffsetX * geo.size.width)
            .opacity(beamOpacity)
            .blendMode(.screen)
    }

    private func questionMarksLayer(geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(qmarks.indices, id: \.self) { i in
                let q = qmarks[i]
                Text("?")
                    .font(.system(size: q.size, weight: .heavy, design: .rounded))
                    .foregroundColor(q.color)
                    .rotationEffect(.degrees(q.rotation))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
                    .opacity(qmarkOpacities[i])
                    .offset(y: qmarkOffsets[i])
                    .position(
                        x: q.xFrac * geo.size.width,
                        y: q.yFrac * geo.size.height
                    )
            }
        }
    }

    private func whoSTheLabel(geo: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            Text("WHO'S")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 3)
                .offset(y: whosOffset)
                .opacity(whosOpacity)

            Text("THE")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.splashYellow)
                .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 3)
                .offset(y: theOffset)
                .opacity(theOpacity)
        }
        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.22)
    }

    private func logoStack(geo: GeometryProxy) -> some View {
        ZStack {
            // Drop shadow ellipse
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.black.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    )
                )
                .frame(width: 160, height: 24)
                .offset(y: 133)
                .scaleEffect(x: shadowScaleX, y: 1)
                .opacity(shadowOpacity)

            // Ring 1 — white
            RoundedRectangle(cornerRadius: 48)
                .stroke(Color.white.opacity(0.7), lineWidth: 3)
                .frame(width: 230, height: 230)
                .scaleEffect(ring1Scale)
                .opacity(ring1Opacity)

            // Ring 2 — yellow
            RoundedRectangle(cornerRadius: 48)
                .stroke(Color.splashYellow.opacity(0.85), lineWidth: 3)
                .frame(width: 230, height: 230)
                .scaleEffect(ring2Scale)
                .opacity(ring2Opacity)

            // Logo with shine overlay
            ZStack {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(logoBreathing)

                // Shine sweep
                LinearGradient(
                    stops: [
                        .init(color: .clear,               location: 0.30),
                        .init(color: .white.opacity(0.55), location: 0.48),
                        .init(color: .white.opacity(0.80), location: 0.50),
                        .init(color: .white.opacity(0.55), location: 0.52),
                        .init(color: .clear,               location: 0.70),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: logoShineX * 230)
                .blendMode(.overlay)
            }
            .frame(width: 230, height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 48))
            .overlay(
                RoundedRectangle(cornerRadius: 48)
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 18)
        }
        .scaleEffect(logoScale)
        .rotationEffect(.degrees(logoRotation))
        .opacity(logoOpacity)
        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.44)
    }

    private func headlineBlock(geo: GeometryProxy) -> some View {
        let headlineY = geo.size.height * 0.76
        return VStack(spacing: 0) {
            // "IMPOSTER?" letters
            HStack(spacing: 0) {
                ForEach(imposterLetters.indices, id: \.self) { i in
                    let letter = imposterLetters[i]
                    Text(letter.char)
                        .font(.system(
                            size: letter.isQ ? 68 : 54,
                            weight: .heavy,
                            design: .rounded
                        ))
                        .foregroundColor(letter.isQ ? .splashYellow : .white)
                        .shadow(
                            color: letter.isQ
                                ? Color.splashYellow.opacity(0.35)
                                : Color.black.opacity(0.35),
                            radius: letter.isQ ? 10 : 0,
                            x: 0,
                            y: letter.isQ ? 10 : 4
                        )
                        .opacity(letterOpacities[i])
                        .offset(y: letterOffsets[i])
                        .scaleEffect(letterScales[i])
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 8)

            // Yellow underline slash
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.splashYellow)
                .frame(width: slashWidth, height: 5)
                .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 2)
                .padding(.top, 10)
        }
        .position(x: geo.size.width * 0.5, y: headlineY)
    }

    private func bottomTagline(geo: GeometryProxy) -> some View {
        Text("FIND  •  ACCUSE  •  SURVIVE")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .tracking(3.5)
            .opacity(taglineOpacity)
            .offset(y: taglineOffset)
            .position(x: geo.size.width * 0.5, y: geo.size.height * 0.865)
    }

    private func loadingDots(geo: GeometryProxy) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 8, height: 8)
                    .offset(y: dotOffsets[i])
            }
        }
        .opacity(dotsOpacity)
        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.925)
    }

    private func wipeOverlay(geo: GeometryProxy) -> some View {
        Circle()
            .fill(Color.white)
            .frame(
                width: max(geo.size.width, geo.size.height) * 2.5,
                height: max(geo.size.width, geo.size.height) * 2.5
            )
            .scaleEffect(wipeScale)
    }

    // MARK: - Animation sequencer

    private func triggerAnimation() {
        // ── Background breathing ──────────────────────────────────
        withAnimation(.easeInOut(duration: 4.0)) {
            bgScale = 1.0
        }

        // ── Grid fade in then out ─────────────────────────────────
        withAnimation(.easeOut(duration: 0.6)) {
            gridOpacity = 0.55
        }
        withAnimation(.easeIn(duration: 0.5).delay(3.4)) {
            gridOpacity = 0.0
        }

        // ── Spotlight sweep (starts at 0.2 s) ────────────────────
        after(0.2) {
            withAnimation(.easeOut(duration: 0.25)) {
                self.spotlightOpacity = 0.9
            }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 3.8)) {
                self.spotlightOffsetX = 0.12
                self.spotlightOffsetY = 0.0
                self.spotlightScale = 1.2
            }
            withAnimation(.easeIn(duration: 0.4).delay(3.2)) {
                self.spotlightOpacity = 0.0
            }
        }

        // ── Logo pop-in (0.42 s) ─────────────────────────────────
        after(0.42) {
            withAnimation(.interpolatingSpring(mass: 0.9, stiffness: 220, damping: 14, initialVelocity: 0)) {
                self.logoScale    = 1.0
                self.logoOpacity  = 1.0
                self.logoRotation = 0.0
            }
        }

        // Drop-shadow
        after(0.5) {
            withAnimation(.easeOut(duration: 0.7)) {
                self.shadowScaleX  = 1.0
                self.shadowOpacity = 0.7
            }
        }

        // ── Ring 1 — white (0.7 s) ───────────────────────────────
        after(0.7) {
            self.ring1Opacity = 1.0
            withAnimation(.easeOut(duration: 1.3)) {
                self.ring1Scale = 1.45
            }
            withAnimation(.easeIn(duration: 1.1).delay(0.05)) {
                self.ring1Opacity = 0.0
            }
        }

        // ── Ring 2 — yellow (0.9 s) ──────────────────────────────
        after(0.9) {
            self.ring2Opacity = 1.0
            withAnimation(.easeOut(duration: 1.3)) {
                self.ring2Scale = 1.45
            }
            withAnimation(.easeIn(duration: 1.1).delay(0.05)) {
                self.ring2Opacity = 0.0
            }
        }

        // ── Logo breathing (starts gentle at 1.4 s) ──────────────
        after(1.4) {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                self.logoBreathing = 1.03
            }
        }

        // ── Logo shine sweep (1.8 s) ─────────────────────────────
        after(1.8) {
            withAnimation(.easeOut(duration: 0.9)) {
                self.logoShineX = 1.5
            }
        }

        // ── "WHO'S" slides in (1.1 s) ────────────────────────────
        after(1.1) {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.7)) {
                self.whosOpacity = 1.0
                self.whosOffset  = 0
            }
        }
        after(1.25) {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.7)) {
                self.theOpacity = 1.0
                self.theOffset  = 0
            }
        }

        // ── Floating "?" marks (staggered from 1.6 s) ────────────
        for i in qmarks.indices {
            let delay = qmarks[i].delay
            after(delay) {
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.65)) {
                    self.qmarkOpacities[i] = 0.85
                    self.qmarkOffsets[i]   = 0
                }
            }
        }

        // ── Scanning beam (1.5 s) ─────────────────────────────────
        after(1.5) {
            withAnimation(.easeOut(duration: 0.2)) { self.beamOpacity = 0.6 }
            withAnimation(.easeInOut(duration: 2.2)) { self.beamOffsetX = 1.5 }
            withAnimation(.easeIn(duration: 0.4).delay(1.8)) { self.beamOpacity = 0.0 }
        }

        // ── "IMPOSTER?" letters slam in (staggered from 1.8 s) ───
        for i in imposterLetters.indices {
            let delay = imposterLetters[i].delay
            after(delay) {
                withAnimation(.interpolatingSpring(mass: 0.7, stiffness: 320, damping: 11, initialVelocity: 0)) {
                    self.letterOpacities[i] = 1.0
                    self.letterOffsets[i]   = 0
                    self.letterScales[i]    = 1.0
                }
            }
        }

        // ── Yellow slash grows (2.5 s) ────────────────────────────
        after(2.5) {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5)) {
                self.slashWidth = 140
            }
        }

        // ── Bottom tagline (2.7 s) ───────────────────────────────
        after(2.7) {
            withAnimation(.easeOut(duration: 0.6)) {
                self.taglineOpacity = 1.0
                self.taglineOffset  = 0
            }
        }

        // ── Loading dots (2.9 s) ─────────────────────────────────
        after(2.9) {
            withAnimation(.easeOut(duration: 0.4)) { self.dotsOpacity = 1.0 }
            self.startDotBounce()
        }

        // ── White wipe (3.7 s) ───────────────────────────────────
        after(3.7) {
            withAnimation(.timingCurve(0.7, 0, 0.3, 1, duration: 0.5)) {
                self.wipeScale = 3.0
            }
        }

        // ── Navigate (4.2 s) ─────────────────────────────────────
        guard !Self.didScheduleInitialNavigation else { return }
        Self.didScheduleInitialNavigation = true
        after(4.2) {
            self.router.navigate(to: .onboarding)
        }
    }

    private func startDotBounce() {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            dotOffsets[0] = -6
        }
        after(0.15) {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                self.dotOffsets[1] = -6
            }
        }
        after(0.30) {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                self.dotOffsets[2] = -6
            }
        }
    }

    // MARK: - Helpers

    /// Convenience: schedule work on main queue after `seconds`.
    private func after(_ seconds: Double, execute work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
