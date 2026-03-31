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
        AvatarColors.color(for: currentIndex)
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
                        if currentPlayer.isImposter {
                            Image(systemName: "person.fill.questionmark")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(.white)

                            Text("You are the IMPOSTER")
                                .font(.system(size: 30, weight: .black))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Your secret word is:")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black.opacity(0.8))

                            Text(currentPlayer.secretWord)
                                .font(.system(size: 42, weight: .black))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.6)
                                .lineLimit(2)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, UIScreen.main.bounds.height * 0.28)
                .padding(.bottom, UIScreen.main.bounds.height * 0.18)
            }

            // Cover image (draggable)
            VStack {
                // Player number
                HStack {
                    Button(action: {
                        if currentIndex == 0 {
                            router.pop()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .opacity(currentIndex == 0 ? 1.0 : 0.0)
                    .disabled(currentIndex != 0)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text("\(currentIndex + 1)")
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(.white)

                Spacer()

                // Character emoji
                ZStack {
                    Circle()
                        .fill(revealColor.opacity(0.5))
                        .frame(width: 200, height: 200)

                    Text(PlayerAvatars.avatar(for: currentIndex))
                        .font(.system(size: 100))
                }

                Spacer()

                // Bottom prompt / action area
                VStack(spacing: 10) {
                    if hasSeenCurrentWord {
                        if isLastPlayer {
                            Text("Everyone has seen the word")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                        } else if let next = nextPlayer {
                            Text("Pass the phone to \(next.name)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: {
                            continueTapped()
                        }) {
                            Text(isLastPlayer ? "Start Game" : "Continue")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 31))
                        }
                        .padding(.horizontal, 40)
                    } else {
                        Text("Swipe up to reveal\nthe secret word")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }

                    Image(systemName: "chevron.up")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: -4)
                }
                .padding(.bottom, 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(revealColor)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height < 0 {
                            // Lift the cover only up to roughly mid-screen while dragging.
                            let maxLift = -UIScreen.main.bounds.height * 0.5
                            dragOffset = max(value.translation.height, maxLift)
                        }
                    }
                    .onEnded { value in
                        if value.translation.height < -80 {
                            HapticsManager.impact(.light)
                            hasSeenCurrentWord = true
                        }
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
