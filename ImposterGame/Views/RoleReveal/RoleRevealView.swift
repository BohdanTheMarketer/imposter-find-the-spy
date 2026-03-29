import SwiftUI

struct RoleRevealView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var dragOffset: CGFloat = 0
    @State private var isRevealed = false
    @State private var showPassPrompt = false
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

            if showPassPrompt {
                passPromptView
            } else {
                roleRevealContent
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Reset state when view appears
            currentIndex = 0
            dragOffset = 0
            isRevealed = false
            showPassPrompt = false
        }
    }

    // MARK: - Role Reveal Content
    private var roleRevealContent: some View {
        ZStack {
            // Secret word underneath
            VStack {
                Spacer()

                if currentPlayer.isImposter {
                    VStack(spacing: 16) {
                        Text("🕵️")
                            .font(.system(size: 60))
                        Text("You are the\nIMPOSTER!")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        if !currentPlayer.secretWord.isEmpty {
                            Text(currentPlayer.secretWord)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 4)
                        }

                        Text("Blend in. Don't get caught.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Your secret word is:")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))

                        Text(currentPlayer.secretWord)
                            .font(.system(size: 34, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .lineLimit(2)

                        Text("Don't say it out loud!")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)

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

                // Swipe instruction
                VStack(spacing: 8) {
                    Text("Swipe up to reveal\nthe secret word")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Image(systemName: "chevron.up")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .offset(y: -4)
                }
                .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(revealColor)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height < 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height < -150 {
                            // Reveal
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = -UIScreen.main.bounds.height
                            }
                            HapticsManager.impact(.heavy)
                            isRevealed = true

                            // Auto-show pass prompt after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation {
                                    showPassPrompt = true
                                }
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Pass Prompt
    private var passPromptView: some View {
        VStack(spacing: 20) {
            Spacer()

            if isLastPlayer {
                Text("Everyone has seen\ntheir word!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Let the game begin!")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            } else if let next = nextPlayer {
                Text("Pass the phone to")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))

                Text(next.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("Don't peek! 👀")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: {
                HapticsManager.impact(.medium)
                if isLastPlayer {
                    gameSession.gamePhase = .playing
                    router.navigate(to: .gameTimer)
                } else {
                    currentIndex += 1
                    dragOffset = 0
                    isRevealed = false
                    showPassPrompt = false
                }
            }) {
                Text(isLastPlayer ? "Start the Game" : "Continue")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
}
