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
            return Player(name: String(localized: "role_reveal.unknown_player"))
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
            // Neon Night navy world (mock 2e).
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
            GridPatternView(lineColor: .white.opacity(0.05))
                .ignoresSafeArea()
                .allowsHitTesting(false)

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
                    LinearGradient.gameplayBackground
                        .ignoresSafeArea()

                    VStack {
                        Spacer()

                        VStack(spacing: 18) {
                            if currentPlayer.isImposter {
                                ImposterRevealBrandMark()

                                VStack(spacing: 6) {
                                    Text("role_reveal.imposter_lead_in")
                                        .font(.evolventa(size: 20, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.88))

                                    Text("role_reveal.imposter_label")
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
                                        Text("role_reveal.hint_title")
                                            .font(.evolventa(size: 16, weight: .bold))
                                            .foregroundColor(Color(red: 0.98, green: 0.45, blue: 0.48))
                                        Text(verbatim: hint)
                                            .font(.evolventa(size: 18, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.95))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                    }
                                    .padding(.top, 8)
                                }
                            } else {
                                VStack(spacing: 6) {
                                    Text("role_reveal.crew_secret_prefix")
                                        .font(.evolventa(size: 15, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.55))

                                    Text(verbatim: currentPlayer.secretWord)
                                        .font(.evolventa(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.6)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 22)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color.appSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, geo.size.height * 0.56)
                    .padding(.bottom, geo.size.height * 0.18)
            }

            // Cover (draggable): navy world with a contained avatar card (mock 2e).
            ZStack {
                LinearGradient.gameplayBackground
                    .ignoresSafeArea()
                GridPatternView(lineColor: .white.opacity(0.05))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Header: back control + player position
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

                        Text(verbatim: "\(currentIndex + 1) / \(gameSession.players.count)")
                            .font(.evolventa(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        Color.clear.frame(width: 22, height: 22)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 52)

                    if !hasSeenCurrentWord {
                        Text(String(format: String(localized: "role_reveal.pass_phone_format"), currentPlayer.name))
                            .font(.evolventa(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 14)
                            .padding(.horizontal, 24)
                    }

                    // Contained avatar card
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(revealScreenColor)
                        if let portrait = PlayerProfiles.roleRevealUIImage(for: currentPlayer.avatarIndex) {
                            Image(uiImage: portrait)
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 16)
                    .padding(.horizontal, 28)
                    .padding(.top, 18)

                    Spacer()

                    VStack(spacing: 12) {
                        if hasSeenCurrentWord {
                            if isLastPlayer {
                                Text("role_reveal.all_done")
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            } else if let next = nextPlayer {
                                Text(String(format: String(localized: "role_reveal.pass_phone_format"), next.name))
                                    .font(.evolventa(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }

                            Button(action: {
                                continueTapped()
                            }) {
                                Text(isLastPlayer
                                     ? LocalizedStringKey("role_reveal.start_game")
                                     : LocalizedStringKey("common.continue"))
                                    .font(.evolventa(size: 20, weight: .bold))
                                    .foregroundColor(.appTextOnAccent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.appAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 28))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                                    .shadow(color: Color.appAccent.opacity(0.45), radius: 12, x: 0, y: 6)
                            }
                            .padding(.horizontal, 28)
                        } else {
                            Text("role_reveal.swipe_instruction")
                                .font(.evolventa(size: 19, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Image(systemName: "chevron.up")
                                .font(.evolventa(size: 24, weight: .bold))
                                .foregroundColor(.appAccent)
                                .offset(y: -2)
                        }
                    }
                    .padding(.bottom, 40)
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

            // Spy emoji mark.
            Text(verbatim: "🕵️")
                .font(.system(size: 66))
        }
        .accessibilityLabel(Text("role_reveal.imposter_label"))
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
