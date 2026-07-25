import SwiftUI

struct VotingView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @EnvironmentObject var localization: LocalizationService
    @State private var selectedPlayerIDs: Set<UUID> = []

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
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

    private var selectCountInstruction: String {
        localization.localizedPluralFormat("voting.select_count", maxSelections)
    }

    private var selectedCountLabel: String {
        localization.localizedFormat(
            "voting.selected_count_format",
            selectedIndices.count,
            maxSelections
        )
    }

    var body: some View {
        let _ = localization.currentLocaleCode

        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.08)
                )

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("voting.title")
                        .font(.evolventa(size: 24, weight: .bold))
                        .foregroundColor(.gameplayTitle)

                    Text(selectCountInstruction)
                        .font(.evolventa(size: 14))
                        .foregroundColor(.white.opacity(0.6))

                    Text(selectedCountLabel)
                        .font(.evolventa(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.top, 12)
                .padding(.bottom, 14)

                // Player grid
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(gameSession.players) { player in
                            VotingCard(
                                player: player,
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
                                    AnalyticsService.logVotingSelectionChanged(
                                        selectedCount: selectedPlayerIDs.count,
                                        maxSelections: maxSelections
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            Group {
                if hasRequiredSelectionCount {
                    Button(action: {
                        HapticsManager.impact(.heavy)
                        AnalyticsService.logVotingRevealTapped(selectedCount: selectedIndices.count)
                        let selected = selectedIndices
                        gameSession.votedPlayerIndices = selected
                        let engine = GameEngine()
                        gameSession.gameResult = engine.checkResult(
                            votedPlayerIndices: selected,
                            players: gameSession.players
                        )
                        router.navigate(to: .result)
                    }) {
                        Text("voting.reveal")
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.appTextOnAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gameplayButtonPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .shadow(color: Color.appAccent.opacity(0.45), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Color.clear.frame(height: 56)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .onAppear {
            selectedPlayerIDs = []
        }
    }
}

struct VotingCard: View {
    let player: Player
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                PlayerAvatarSquareTileView(avatarIndex: player.avatarIndex)
                    .aspectRatio(1.0, contentMode: .fit)

                Text(verbatim: player.name)
                    .font(.evolventa(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gameplaySurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.appAccent : Color.white.opacity(0.06), lineWidth: isSelected ? 2.5 : 1)
            )
            // Pink "voted" check badge (mock 2g)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.evolventa(size: 13, weight: .bold))
                        .foregroundColor(.appTextOnAccent)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.appAccent))
                        .padding(10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: Color.appAccent.opacity(isSelected ? 0.5 : 0.0), radius: 16, x: 0, y: 0)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Voting cards") {
    HStack(spacing: 12) {
        VotingCard(
            player: Player(name: "Alex", avatarIndex: 0),
            isSelected: false,
            onTap: {}
        )
        VotingCard(
            player: Player(name: "Jordan", avatarIndex: 7),
            isSelected: true,
            onTap: {}
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.08, green: 0.08, blue: 0.1))
}
