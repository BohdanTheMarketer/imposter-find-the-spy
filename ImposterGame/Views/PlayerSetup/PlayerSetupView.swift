import SwiftUI
import UIKit

struct PlayerEntry: Identifiable {
    let id = UUID()
    var name: String
}

struct PlayerSetupView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @State private var players: [PlayerEntry] = []
    @State private var newPlayerName: String = ""
    @State private var showOptionsMenu = false
    @FocusState private var isTextFieldFocused: Bool

    private let minPlayers = 3
    private let maxPlayers = 15

    var canContinue: Bool {
        let validNames = players.map { $0.name.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let uniqueNames = Set(validNames.map { $0.lowercased() })
        return validNames.count >= minPlayers && uniqueNames.count == validNames.count
    }

    private var playerCountLabel: String {
        "\(players.count) Player\(players.count == 1 ? "" : "s")"
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
                        .font(.evolventa(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button(action: {
                        HapticsManager.impact(.light)
                        showOptionsMenu = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.evolventa(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(white: 0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

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
                .padding(.bottom, 8)

                // Add player input stays under the list
                HStack(spacing: 12) {
                    TextField("Enter player name", text: $newPlayerName)
                        .font(.evolventa(size: 17, weight: .semibold))
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
                            .font(.evolventa(size: 20, weight: .bold))
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

                // Bottom continue button with player count
                Button(action: {
                    guard canContinue else {
                        HapticsManager.notification(.warning)
                        return
                    }

                        HapticsManager.impact(.medium)
                        isTextFieldFocused = false
                        setupPlayers()
                        router.navigate(to: .categories)
                    }) {
                    HStack(spacing: 14) {
                        Text("CONTINUE")
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 1, height: 26)
                        Text(playerCountLabel)
                            .font(.evolventa(size: 20, weight: .semibold))
                            .foregroundColor(.black.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .opacity(canContinue ? 1.0 : 0.85)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: canContinue)
        .onAppear {
            syncLocalPlayersFromSession()
        }
        .sheet(isPresented: $showOptionsMenu) {
            PlayerOptionsSheet(isPresented: $showOptionsMenu)
        }
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

    /// `PlayerSetupView` keeps its own list until Continue; when returning from Categories or after Play Again, repopulate from the session.
    private func syncLocalPlayersFromSession() {
        guard !gameSession.players.isEmpty else { return }
        players = gameSession.players.map { PlayerEntry(name: $0.name) }
    }
}

// MARK: - Options sheet (gear on Players screen)

private enum AppUserIdentity {
    private static let key = "app_anonymous_user_id"

    static var id: String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}

private enum PlayerOptionsLinks {
    /// Replace with your App Store support email before release.
    static let contactEmail = "support@example.com"
    /// Replace with live URLs when available.
    static let privacyURL = URL(string: "https://example.com/privacy")
    static let termsURL = URL(string: "https://example.com/terms")
}

struct PlayerOptionsSheet: View {
    @Binding var isPresented: Bool
    @State private var vibrationOn = HapticsManager.isEnabled

    var body: some View {
        ZStack {
            LinearGradient.appRedGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                Text("Options")
                    .font(.evolventa(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                VStack(spacing: 0) {
                    optionRow(title: "Language", systemImage: "globe") {
                        openURLString(UIApplication.openSettingsURLString)
                    }
                    Divider().background(Color.white.opacity(0.2))
                    optionRow(title: "Contact Us", systemImage: "envelope") {
                        if let url = URL(string: "mailto:\(PlayerOptionsLinks.contactEmail)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(Color.white.opacity(0.2))
                    optionRow(title: "Privacy", systemImage: "shield") {
                        if let url = PlayerOptionsLinks.privacyURL {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(Color.white.opacity(0.2))
                    optionRow(title: "Terms of Use", systemImage: "doc.text") {
                        if let url = PlayerOptionsLinks.termsURL {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(Color.white.opacity(0.2))
                    vibrationRow
                }
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                Text("User ID: \(AppUserIdentity.id)")
                    .font(.evolventa(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .textSelection(.enabled)

                Spacer(minLength: 12)

                Button(action: {
                    HapticsManager.impact(.light)
                    isPresented = false
                }) {
                    Text("Close")
                        .font(.evolventa(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            vibrationOn = HapticsManager.isEnabled
        }
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
    }

    private var vibrationRow: some View {
        HStack {
            Text("Vibration")
                .font(.evolventa(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.evolventa(size: 20, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .padding(.trailing, 8)
            Toggle("", isOn: $vibrationOn)
                .labelsHidden()
                .tint(.green)
                .onChange(of: vibrationOn) { newValue in
                    HapticsManager.isEnabled = newValue
                    if newValue {
                        HapticsManager.impact(.light)
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func optionRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticsManager.impact(.light)
            action()
        }) {
            HStack {
                Text(title)
                    .font(.evolventa(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: systemImage)
                    .font(.evolventa(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openURLString(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
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
                .font(.evolventa(size: 28))
                .frame(width: 44, height: 44)
                .background(AvatarColors.color(for: index))
                .clipShape(Circle())

            Text(name)
                .font(.evolventa(size: 17, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.evolventa(size: 22))
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
