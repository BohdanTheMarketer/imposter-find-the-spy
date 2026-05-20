import SwiftUI

struct GameTimerView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var timeRemaining: Int = 120
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var showPauseMenu = false
    private let timerRingSize: CGFloat = 240

    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var totalDuration: Int {
        max(gameSession.settings.roundDuration, 1)
    }

    private var progress: CGFloat {
        CGFloat(max(timeRemaining, 0)) / CGFloat(totalDuration)
    }

    private var ringColor: Color {
        if timeRemaining <= 10 {
            return .revealOrange
        }
        return .appAccent
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
                HStack {
                    Button(action: {
                        HapticsManager.impact(.light)
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            showPauseMenu = true
                        }
                        pauseTimer()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.evolventa(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.gameplaySurface.opacity(0.9))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 4) {
                    Text("\(gameSession.startingPlayerIndex + 1)")
                        .font(.evolventa(size: 56, weight: .bold))
                        .foregroundColor(.white)

                    Text("Starts Asking!")
                        .font(.evolventa(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                VStack(spacing: 14) {
                    Text("Timer")
                        .font(.evolventa(size: 12, weight: .bold))
                        .foregroundColor(.appAccent)
                        .tracking(1.3)
                        .textCase(.uppercase)

                    ZStack {
                        Circle()
                            .stroke(Color.gameplayButtonSecondary, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                ringColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.8), value: progress)

                        Text(formattedTime)
                            .font(.evolventa(size: 58, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(width: timerRingSize, height: timerRingSize)
                }

                Spacer()
                Spacer()

                // Space for the pinned bottom control bar
                Color.clear
                    .frame(height: 108)
            }

            if showPauseMenu {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            showPauseMenu = false
                        }
                        resumeTimer()
                    }
            }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    if showPauseMenu {
                        Text("Paused")
                            .font(.evolventa(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    HStack(spacing: 12) {
                        if showPauseMenu {
                            Button(action: {
                                HapticsManager.impact(.light)
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                    showPauseMenu = false
                                }
                                resumeTimer()
                            }) {
                                Text("Continue")
                                    .font(.evolventa(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.gameplayButtonSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 26))
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            ))

                            Button(action: {
                                HapticsManager.impact(.medium)
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                    showPauseMenu = false
                                }
                                stopTimer()
                                gameSession.gamePhase = .voting
                                router.navigate(to: .voting)
                            }) {
                                Text("Vote Now")
                                    .font(.evolventa(size: 17, weight: .bold))
                                    .foregroundColor(.appTextOnAccent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.gameplayButtonPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 26))
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                        } else {
                            Button(action: {
                                HapticsManager.impact(.medium)
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                    showPauseMenu = true
                                }
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
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showPauseMenu)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

                Rectangle()
                    .fill(Color.gameplayButtonPrimary)
                    .frame(height: 4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
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
