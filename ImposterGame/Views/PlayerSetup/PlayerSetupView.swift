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
    /// Bumped to programmatically focus the UIKit name field (see `PlayerNameEntryField`).
    @State private var nameFieldFocusToken = 0

    private let minPlayers = 3
    private let maxPlayers = 15

    private var validPlayerNames: [String] {
        players.map { $0.name.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var validPlayerCount: Int { validPlayerNames.count }

    var canContinue: Bool {
        let uniqueNames = Set(validPlayerNames.map { $0.lowercased() })
        return validPlayerCount >= minPlayers && uniqueNames.count == validPlayerCount
    }

    private var playerCountLabel: String {
        "\(players.count) Player\(players.count == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var bottomChrome: some View {
        VStack(spacing: 16) {
            if players.count < maxPlayers {
                HStack(spacing: 12) {
                    PlayerNameEntryField(
                        text: $newPlayerName,
                        placeholder: "Enter player name",
                        onCommit: addPlayer,
                        focusToken: nameFieldFocusToken
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 25))

                    Button(action: addPlayer) {
                        Image(systemName: "plus")
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Color(white: 0.15))
                            .clipShape(Circle())
                    }
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20)
            }

            Group {
                if validPlayerCount >= minPlayers {
                    Button(action: {
                        guard canContinue else {
                            HapticsManager.notification(.warning)
                            return
                        }

                        HapticsManager.impact(.medium)
                        PlayerSetupKeyboard.dismiss()
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
                    .opacity(canContinue ? 1.0 : 0.85)
                } else {
                    Text("Minimum 3 players to start a game")
                        .font(.evolventa(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
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

                ScrollViewReader { proxy in
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
                                    .id(entry.id)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        PlayerSetupKeyboard.dismiss()
                    }
                    .frame(maxHeight: .infinity)
                    .onChange(of: players.count) { _ in
                        scrollToLastPlayer(using: proxy)
                    }
                    .onAppear {
                        scrollToLastPlayer(using: proxy)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: validPlayerCount)
        .animation(.easeInOut(duration: 0.3), value: canContinue)
        .onAppear {
            syncLocalPlayersFromSession()
            let shouldShowKeyboard = players.count < maxPlayers
            guard shouldShowKeyboard else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFieldFocusToken &+= 1
            }
        }
        .sheet(isPresented: $showOptionsMenu) {
            PlayerOptionsSheet(isPresented: $showOptionsMenu)
        }
        .onChange(of: players.count) { _ in
            if players.count >= maxPlayers {
                PlayerSetupKeyboard.dismiss()
            }
        }
    }

    private func scrollToLastPlayer(using proxy: ScrollViewProxy) {
        guard let lastId = players.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
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

// MARK: - Name field (UIKit for reliable keyboard in safeAreaInset)

private enum PlayerSetupKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct PlayerNameEntryField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var focusToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.textColor = .white
        tf.tintColor = .white
        tf.font = UIFont(name: "Evolventa-Bold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.45)]
        )
        tf.borderStyle = .none
        tf.backgroundColor = .clear
        tf.returnKeyType = .done
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .words
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PlayerNameEntryField!
        /// Starts aligned with `nameFieldFocusToken` so the initial `0` does not auto-focus.
        var lastFocusToken: Int = 0

        @objc func editingChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit()
            return false
        }
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
