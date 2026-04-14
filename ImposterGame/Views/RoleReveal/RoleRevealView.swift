import SwiftUI

struct RoleRevealView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var dragOffset: CGFloat = 0
    @State private var hasSeenCurrentWord = false
    @State private var currentIndex = 0
    @State private var revealScreenColor: Color = AvatarColors.color(for: 0)

    private var currentPlayer: Player {
        guard currentIndex < gameSession.players.count else {
            return Player(name: "Unknown")
        }
        return gameSession.players[currentIndex]
    }

    private var isLastPlayer: Bool {
        currentIndex >= gameSession.players.count - 1
    }

    private var nextPlayer: Player? {
        let nextIdx = currentIndex + 1
        guard nextIdx < gameSession.players.count else { return nil }
        return gameSession.players[nextIdx]
    }

    private var currentImposterHint: String? {
        guard currentPlayer.isImposter else { return nil }
        let hint = currentPlayer.secretWord.trimmingCharacters(in: .whitespacesAndNewlines)
        return hint.isEmpty ? nil : hint
    }

    var body: some View {
        ZStack {
            // Background matches sampled portrait backdrop when possible.
            revealScreenColor
                .ignoresSafeArea()

            roleRevealContent
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Reset state when view appears
            currentIndex = 0
            dragOffset = 0
            hasSeenCurrentWord = false
            syncRevealBackdrop()
        }
        .onChange(of: currentIndex) { _ in
            syncRevealBackdrop()
        }
    }

    // MARK: - Role Reveal Content
    private var roleRevealContent: some View {
        GeometryReader { geo in
        ZStack {
            // Revealed content underneath the top card.
            ZStack {
                    (currentPlayer.isImposter ? Color.black : revealScreenColor)
                        .ignoresSafeArea()

                    VStack {
                        Spacer()

                        VStack(spacing: 18) {
                            if currentPlayer.isImposter {
                                ImposterRevealBrandMark()

                                VStack(spacing: 6) {
                                    Text("You are the")
                                        .font(.evolventa(size: 20, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.88))

                                    Text("IMPOSTER")
                                        .font(.evolventa(size: 34, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.35, blue: 0.38),
                                                    Color(red: 0.92, green: 0.12, blue: 0.2),
                                                    Color(red: 0.72, green: 0.06, blue: 0.12)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.red.opacity(0.45), radius: 12, x: 0, y: 0)
                                        .multilineTextAlignment(.center)
                                }

                                // Show the imposter hint only after the swipe-up reveal interaction.
                                if hasSeenCurrentWord, let hint = currentImposterHint {
                                    VStack(spacing: 8) {
                                        Text("Imposter hint")
                                            .font(.evolventa(size: 16, weight: .bold))
                                            .foregroundColor(Color(red: 0.98, green: 0.45, blue: 0.48))
                                        Text(hint)
                                            .font(.evolventa(size: 18, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.95))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                    }
                                    .padding(.top, 8)
                                }
                            } else {
                                Text("Your secret word is:")
                                    .font(.evolventa(size: 18, weight: .semibold))
                                    .foregroundColor(.black.opacity(0.8))

                                Text(currentPlayer.secretWord)
                                    .font(.evolventa(size: 42, weight: .bold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, geo.size.height * 0.56)
                    .padding(.bottom, geo.size.height * 0.18)
            }

            // Cover (draggable): centered portrait with top/bottom chrome overlaid.
            ZStack {
                revealScreenColor
                    .ignoresSafeArea()

                Group {
                    if let portrait = PlayerProfiles.roleRevealUIImage(for: currentPlayer.avatarIndex) {
                        Image(uiImage: portrait)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.52)
                            .clipped()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            if currentIndex == 0 {
                                router.pop()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.evolventa(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .opacity(currentIndex == 0 ? 1.0 : 0.0)
                        .disabled(currentIndex != 0)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Text("\(currentIndex + 1)")
                        .font(.evolventa(size: 40, weight: .black))
                        .foregroundColor(.white)
                        .padding(.top, 14)

                    Spacer()
                    VStack(spacing: 10) {
                        if hasSeenCurrentWord {
                            if isLastPlayer {
                                Text("Everyone has seen the word")
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                            } else if let next = nextPlayer {
                                Text("Pass the phone to \(next.name)")
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                            }

                            Button(action: {
                                continueTapped()
                            }) {
                                Text(isLastPlayer ? "Start Game" : "Continue")
                                    .font(.evolventa(size: 20, weight: .black))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 62)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 31))
                            }
                            .padding(.horizontal, 40)
                        } else {
                            Text("Swipe up to reveal\nthe secret word")
                                .font(.evolventa(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }

                        Image(systemName: "chevron.up")
                            .font(.evolventa(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: -4)
                    }
                    .padding(.bottom, 36)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height < 0 {
                            // Lift the cover only up to roughly mid-screen while dragging.
                            let maxLift = -geo.size.height * 0.5
                            dragOffset = max(value.translation.height, maxLift)

                            // Mark as revealed as soon as swipe crosses the threshold,
                            // so hint/role content is visible during the first reveal swipe.
                            if !hasSeenCurrentWord, value.translation.height < -80 {
                                HapticsManager.impact(.light)
                                hasSeenCurrentWord = true
                            }
                        }
                    }
                    .onEnded { value in
                        // Always return the cover when the finger is released.
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        }
        .ignoresSafeArea()
    }

    private func continueTapped() {
        HapticsManager.impact(.medium)
        if isLastPlayer {
            gameSession.gamePhase = .playing
            router.navigate(to: .gameTimer)
        } else {
            currentIndex += 1
            dragOffset = 0
            hasSeenCurrentWord = false
        }
    }

    private func syncRevealBackdrop() {
        revealScreenColor = AvatarColors.color(for: currentPlayer.avatarIndex)
    }
}

// MARK: - Imposter brand (role reveal)

/// Vector mark for the imposter role — not a player photo; reads as a disguise / hidden identity.
private struct ImposterRevealBrandMark: View {
    private let fillGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.28, blue: 0.32),
            Color(red: 0.78, green: 0.08, blue: 0.14),
            Color(red: 0.55, green: 0.02, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(fillGradient)
                .frame(width: 118, height: 118)
                .shadow(color: Color.red.opacity(0.42), radius: 22, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

            // Hood + anonymous “visor” silhouette (white on red).
            ImposterMarkGlyph()
                .frame(width: 72, height: 72)
        }
        .accessibilityLabel("Imposter")
    }
}

private struct ImposterMarkGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let hood = Path { p in
                p.move(to: CGPoint(x: w * 0.12, y: h * 0.72))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.08),
                    control: CGPoint(x: w * 0.02, y: h * 0.32)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.88, y: h * 0.72),
                    control: CGPoint(x: w * 0.98, y: h * 0.32)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.5, y: h * 0.88),
                    control: CGPoint(x: w * 0.78, y: h * 0.95)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.12, y: h * 0.72),
                    control: CGPoint(x: w * 0.22, y: h * 0.95)
                )
                p.closeSubpath()
            }
            context.fill(hood, with: .color(.white.opacity(0.95)))

            // Visor band — negative space feel
            let visor = Path { p in
                p.move(to: CGPoint(x: w * 0.22, y: h * 0.42))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.78, y: h * 0.42),
                    control: CGPoint(x: w * 0.5, y: h * 0.36)
                )
                p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.58))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.24, y: h * 0.58),
                    control: CGPoint(x: w * 0.5, y: h * 0.64)
                )
                p.closeSubpath()
            }
            context.fill(visor, with: .color(Color(red: 0.55, green: 0.02, blue: 0.08).opacity(0.92)))

            // Eyes
            let eyeL = Path(ellipseIn: CGRect(x: w * 0.32, y: h * 0.46, width: w * 0.1, height: h * 0.08))
            let eyeR = Path(ellipseIn: CGRect(x: w * 0.58, y: h * 0.46, width: w * 0.1, height: h * 0.08))
            context.fill(eyeL, with: .color(.white.opacity(0.92)))
            context.fill(eyeR, with: .color(.white.opacity(0.92)))
        }
    }
}

// MARK: - Previews

private enum RoleRevealPreviewData {
    static func session(imposterAt: Int? = nil) -> GameSession {
        let session = GameSession()
        var a = Player(name: "Alex", avatarIndex: 0)
        a.secretWord = "Waterfall"
        var b = Player(name: "Jordan", avatarIndex: 4)
        b.secretWord = "Lantern"
        var c = Player(name: "Sam", avatarIndex: 9)
        c.secretWord = "Velvet"
        var players = [a, b, c]
        if let i = imposterAt, i >= 0, i < players.count {
            players[i].isImposter = true
            players[i].secretWord = "Echo hint"
        }
        session.players = players
        return session
    }
}

#Preview("Role reveal — crew") {
    RoleRevealView()
        .environmentObject(AppRouter())
        .environmentObject(RoleRevealPreviewData.session(imposterAt: nil))
}

#Preview("Role reveal — imposter middle") {
    RoleRevealView()
        .environmentObject(AppRouter())
        .environmentObject(RoleRevealPreviewData.session(imposterAt: 1))
}
