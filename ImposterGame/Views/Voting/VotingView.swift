import SwiftUI

struct VotingView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var selectedPlayerIDs: Set<UUID> = []

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var maxSelections: Int {
        max(1, gameSession.settings.imposterCount)
    }

    private var selectedIndices: [Int] {
        gameSession.players.indices.filter { selectedPlayerIDs.contains(gameSession.players[$0].id) }
    }

    private var hasRequiredSelectionCount: Bool {
        selectedPlayerIDs.count == maxSelections
    }

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.08)
                )

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Who's the Imposter?")
                        .font(.evolventa(size: 28, weight: .bold))
                        .foregroundColor(.gameplayTitle)

                    Text("Select \(maxSelections) player\(maxSelections == 1 ? "" : "s") you think are faking it")
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
                                isSelected: selectedPlayerIDs.contains(player.id),
                                onTap: {
                                    HapticsManager.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedPlayerIDs.contains(player.id) {
                                            selectedPlayerIDs.remove(player.id)
                                        } else if selectedPlayerIDs.count < maxSelections {
                                            selectedPlayerIDs.insert(player.id)
                                        }
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
                if hasRequiredSelectionCount {
                    Button(action: {
                        HapticsManager.impact(.heavy)
                        let selected = selectedIndices
                        gameSession.votedPlayerIndices = selected
                        let engine = GameEngine()
                        gameSession.gameResult = engine.checkResult(
                            votedPlayerIndices: selected,
                            players: gameSession.players
                        )
                        router.navigate(to: .result)
                    }) {
                        Text("Reveal")
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gameplayButtonPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            selectedPlayerIDs = []
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
                    .fill(Color.gameplaySurface)
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
