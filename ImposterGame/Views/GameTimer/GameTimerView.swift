import SwiftUI

struct GameTimerView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var timeRemaining: Int = 120
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var showPauseMenu = false

    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var startingPlayerName: String {
        guard gameSession.startingPlayerIndex < gameSession.players.count else { return "?" }
        return gameSession.players[gameSession.startingPlayerIndex].name
    }

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.05)
                )

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        showPauseMenu = true
                        pauseTimer()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.evolventa(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Starting player info
                VStack(spacing: 4) {
                    Text("\(gameSession.startingPlayerIndex + 1)")
                        .font(.evolventa(size: 40, weight: .bold))
                        .foregroundColor(.white)

                    Text("Starts Asking!")
                        .font(.evolventa(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Timer display
                VStack(spacing: 8) {
                    Text("Timer")
                        .font(.evolventa(size: 20, weight: .bold))
                        .foregroundColor(.gameplayTitle)

                    Text(formattedTime)
                        .font(.evolventa(size: 72, weight: .bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }

                Spacer()
                Spacer()

                // Pause button
                Button(action: {
                    HapticsManager.impact(.medium)
                    showPauseMenu = true
                    pauseTimer()
                }) {
                    Text("Pause")
                        .font(.evolventa(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.gameplayButtonSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

                // Red accent bar
                Rectangle()
                    .fill(Color.gameplayButtonPrimary)
                    .frame(height: 4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }

            // Pause menu overlay
            if showPauseMenu {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showPauseMenu = false
                        resumeTimer()
                    }

                VStack(spacing: 16) {
                    Text("Game Paused")
                        .font(.evolventa(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 8)

                    Button(action: {
                        HapticsManager.impact(.light)
                        showPauseMenu = false
                        resumeTimer()
                    }) {
                        Text("Continue")
                            .font(.evolventa(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.gameplayButtonSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    }

                    Button(action: {
                        HapticsManager.impact(.medium)
                        showPauseMenu = false
                        stopTimer()
                        gameSession.gamePhase = .voting
                        router.navigate(to: .voting)
                    }) {
                        Text("Vote Now")
                            .font(.evolventa(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.gameplayButtonPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            timeRemaining = gameSession.settings.roundDuration
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        stopTimer() // Ensure no duplicate timers
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1

                if timeRemaining == 10 {
                    HapticsManager.notification(.warning)
                }
                if timeRemaining <= 5 && timeRemaining > 0 {
                    HapticsManager.impact(.heavy)
                }
            } else {
                stopTimer()
                HapticsManager.notification(.error)
                gameSession.gamePhase = .voting
                router.navigate(to: .voting)
            }
        }
    }

    private func pauseTimer() {
        stopTimer()
        isPaused = true
    }

    private func resumeTimer() {
        isPaused = false
        startTimer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
