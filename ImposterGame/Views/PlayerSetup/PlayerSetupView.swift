import SwiftUI

struct PlayerEntry: Identifiable {
    let id = UUID()
    var name: String
}

struct PlayerSetupView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var players: [PlayerEntry] = []
    @State private var newPlayerName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    private let minPlayers = 3
    private let maxPlayers = 15

    var canContinue: Bool {
        let validNames = players.map { $0.name.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let uniqueNames = Set(validNames.map { $0.lowercased() })
        return validNames.count >= minPlayers && uniqueNames.count == validNames.count
    }

    var body: some View {
        ZStack {
            // Red gradient background with grid
            LinearGradient.appRedGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Players")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(white: 0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Add player input
                HStack(spacing: 12) {
                    TextField("Enter player name", text: $newPlayerName)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            addPlayer()
                        }
                        .submitLabel(.done)

                    Button(action: addPlayer) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color(white: 0.15))
                            .clipShape(Circle())
                    }
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty || players.count >= maxPlayers)
                    .opacity(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Player list
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(players) { entry in
                            if let index = players.firstIndex(where: { $0.id == entry.id }) {
                                PlayerRow(
                                    name: entry.name,
                                    index: index,
                                    canDelete: true,
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            players.removeAll { $0.id == entry.id }
                                        }
                                        HapticsManager.impact(.light)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onTapGesture {
                    isTextFieldFocused = false
                }

                Spacer()

                // Bottom info / continue
                if canContinue {
                    Button(action: {
                        HapticsManager.impact(.medium)
                        isTextFieldFocused = false
                        setupPlayers()
                        router.navigate(to: .categories)
                    }) {
                        Text("Continue")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text(players.isEmpty
                         ? "Add at least \(minPlayers) players to continue"
                         : "Add \(max(0, minPlayers - players.count)) more player\(minPlayers - players.count == 1 ? "" : "s") to continue")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: canContinue)
    }

    private func addPlayer() {
        let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, players.count < maxPlayers else { return }

        // Check for duplicates
        let isDuplicate = players.contains { $0.name.lowercased().trimmingCharacters(in: .whitespaces) == trimmed.lowercased() }
        if isDuplicate {
            HapticsManager.notification(.warning)
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            players.append(PlayerEntry(name: trimmed))
        }
        newPlayerName = ""
        HapticsManager.impact(.light)
        isTextFieldFocused = true
    }

    private func setupPlayers() {
        gameSession.players = players.enumerated().map { index, entry in
            Player(name: entry.name, avatarIndex: index)
        }
    }
}

struct PlayerRow: View {
    let name: String
    let index: Int
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Text(PlayerAvatars.avatar(for: index))
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(AvatarColors.color(for: index))
                .clipShape(Circle())

            Text(name)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
