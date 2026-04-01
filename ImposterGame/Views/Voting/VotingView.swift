import SwiftUI

struct VotingView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var selectedPlayerID: UUID? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var selectedIndex: Int? {
        guard let id = selectedPlayerID else { return nil }
        return gameSession.players.firstIndex { $0.id == id }
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Who's the Imposter?")
                        .font(.evolventa(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Vote for who you think is faking it")
                        .font(.evolventa(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Player grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(gameSession.players) { player in
                            let index = gameSession.players.firstIndex(where: { $0.id == player.id }) ?? 0
                            VotingCard(
                                player: player,
                                index: index,
                                isSelected: selectedPlayerID == player.id,
                                onTap: {
                                    HapticsManager.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPlayerID = player.id
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }

                Spacer()

                // Reveal button
                Button(action: {
                    guard let selected = selectedIndex else { return }
                    HapticsManager.impact(.heavy)
                    gameSession.votedPlayerIndex = selected
                    let engine = GameEngine()
                    gameSession.gameResult = engine.checkResult(
                        votedPlayerIndex: selected,
                        players: gameSession.players
                    )
                    router.navigate(to: .result)
                }) {
                    Text("Reveal")
                        .font(.evolventa(size: 20, weight: .bold))
                        .foregroundColor(selectedPlayerID != nil ? .black : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedPlayerID != nil ? Color.white : Color(white: 0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .disabled(selectedPlayerID == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            selectedPlayerID = nil
        }
    }
}

struct VotingCard: View {
    let player: Player
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AvatarColors.color(for: index))
                        .aspectRatio(1.0, contentMode: .fit)

                    Text(PlayerAvatars.avatar(for: index))
                        .font(.evolventa(size: 50))
                }

                Text(player.name)
                    .font(.evolventa(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
