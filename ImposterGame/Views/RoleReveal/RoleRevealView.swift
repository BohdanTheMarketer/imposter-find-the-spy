import SwiftUI

struct RoleRevealView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var dragOffset: CGFloat = 0
    @State private var hasSeenCurrentWord = false
    @State private var currentIndex = 0

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

    private var revealColor: Color {
        AvatarColors.color(for: currentPlayer.avatarIndex)
    }

    private var currentImposterHint: String? {
        guard currentPlayer.isImposter else { return nil }
        let hint = currentPlayer.secretWord.trimmingCharacters(in: .whitespacesAndNewlines)
        return hint.isEmpty ? nil : hint
    }

    var body: some View {
        ZStack {
            // Background color
            revealColor
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
        }
    }

    // MARK: - Role Reveal Content
    private var roleRevealContent: some View {
        ZStack {
            // Revealed content underneath the top card.
            ZStack {
                (currentPlayer.isImposter ? Color.black : revealColor)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: 14) {
                        PlayerAvatarThumbnailView(
                            avatarIndex: currentPlayer.avatarIndex,
                            size: 96,
                            cornerRadius: 48
                        )

                        if currentPlayer.isImposter {
                            Image(systemName: "person.fill.questionmark")
                                .font(.evolventa(size: 56, weight: .bold))
                                .foregroundColor(.white)

                            Text("You are the IMPOSTER")
                                .font(.evolventa(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                                // Show the imposter hint only after the swipe-up reveal interaction.
                                if hasSeenCurrentWord, let hint = currentImposterHint {
                                    VStack(spacing: 6) {
                                        Text("Imposter hint")
                                            .font(.evolventa(size: 16, weight: .bold))
                                            .foregroundColor(.white.opacity(0.92))
                                        Text(hint)
                                            .font(.evolventa(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                    }
                                    .padding(.top, 6)
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
                .padding(.top, UIScreen.main.bounds.height * 0.56)
                .padding(.bottom, UIScreen.main.bounds.height * 0.18)
            }

            // Cover (draggable): centered portrait with top/bottom chrome overlaid.
            ZStack {
                revealColor

                Group {
                    if let portrait = PlayerProfiles.roleRevealUIImage(for: currentPlayer.avatarIndex) {
                        Image(uiImage: portrait)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.52)
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
                            let maxLift = -UIScreen.main.bounds.height * 0.5
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
