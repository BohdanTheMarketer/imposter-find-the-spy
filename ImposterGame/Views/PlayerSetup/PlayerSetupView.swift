import FirebaseAnalytics
import FirebaseInstallations
import SwiftUI
import UIKit
import Combine

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
    @State private var keyboardHeight: CGFloat = 0
    private let inputRowScrollId = "player-input-row"

    private let minPlayers = 3
    private let maxPlayers = 15
    private let maxNameLength = 24

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
    private var nameInputSection: some View {
        if players.count < maxPlayers {
            HStack(spacing: 12) {
                PlayerNameEntryField(
                    text: $newPlayerName,
                    placeholder: "Enter player name",
                    onCommit: addPlayer,
                    focusToken: nameFieldFocusToken,
                    maxLength: maxNameLength
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.gameplaySurface)
                .clipShape(RoundedRectangle(cornerRadius: 25))

                Button(action: addPlayer) {
                    Image(systemName: "plus")
                        .font(.evolventa(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(GameplayRoundIconButtonStyle())
                .disabled(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
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
                            .foregroundColor(.white)
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 1, height: 26)
                        Text(playerCountLabel)
                            .font(.evolventa(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.gameplayButtonPrimary)
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
            LinearGradient.gameplayBackground
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
                        .foregroundColor(.gameplayTitle)
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
                            .background(Color.gameplayButtonSecondary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(players.enumerated()), id: \.element.id) { index, entry in
                                PlayerRow(
                                    name: entry.name,
                                    avatarIndex: index,
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

                            nameInputSection
                                .id(inputRowScrollId)
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

                VStack(spacing: 12) {
                    actionSection
                        .animation(.easeInOut(duration: 0.3), value: validPlayerCount)
                        .animation(.easeInOut(duration: 0.3), value: canContinue)
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
                    .padding(.bottom, bottomChromeBottomPadding(safeAreaBottom: geometry.safeAreaInsets.bottom))
            }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private func scrollToLastPlayer(using proxy: ScrollViewProxy) {
        let targetId: AnyHashable
        if players.count < maxPlayers {
            targetId = inputRowScrollId
        } else if let lastId = players.last?.id {
            targetId = lastId
        } else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(targetId, anchor: .bottom)
            }
        }
    }

    private func addPlayer() {
        let trimmed = newPlayerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, players.count < maxPlayers else { return }
        guard trimmed.count <= maxNameLength else {
            HapticsManager.notification(.warning)
            newPlayerName = String(trimmed.prefix(maxNameLength))
            return
        }

        let uniqueName = nextAvailableName(from: trimmed)

        withAnimation(.easeInOut(duration: 0.2)) {
            players.append(PlayerEntry(name: uniqueName))
        }
        newPlayerName = ""
        HapticsManager.impact(.light)
    }

    /// If entered name already exists, append an incrementing suffix: "Name 2", "Name 3", ...
    private func nextAvailableName(from rawName: String) -> String {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        let (baseName, enteredSuffix) = splitNameAndSuffix(name)
        let normalizedBase = baseName.lowercased()
        guard !normalizedBase.isEmpty else { return name }

        var maxUsedSuffix = 0
        for entry in players {
            let existing = entry.name.trimmingCharacters(in: .whitespaces)
            let (existingBase, existingSuffix) = splitNameAndSuffix(existing)
            guard existingBase.lowercased() == normalizedBase else { continue }
            maxUsedSuffix = max(maxUsedSuffix, existingSuffix ?? 1)
        }

        if maxUsedSuffix == 0 {
            return name
        }

        let requestedSuffix = enteredSuffix ?? 1
        let nextSuffix = max(maxUsedSuffix + 1, requestedSuffix)
        return "\(baseName) \(nextSuffix)"
    }

    private func splitNameAndSuffix(_ value: String) -> (base: String, suffix: Int?) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ("", nil) }

        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard let last = parts.last, let suffix = Int(last), parts.count > 1 else {
            return (trimmed, nil)
        }

        let base = parts.dropLast().joined(separator: " ")
        return (base.trimmingCharacters(in: .whitespaces), suffix)
    }

    /// Keeps bottom controls above keyboard while preserving normal spacing.
    private func bottomChromeBottomPadding(safeAreaBottom: CGFloat) -> CGFloat {
        guard keyboardHeight > 0 else { return 16 }
        return max(16, keyboardHeight - safeAreaBottom + 8)
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let frame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        let overlap = max(0, UIScreen.main.bounds.height - frame.minY)
        keyboardHeight = overlap
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
    var maxLength: Int

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

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentText = textField.text ?? ""
            guard let textRange = Range(range, in: currentText) else { return true }
            let updatedText = currentText.replacingCharacters(in: textRange, with: string)
            return updatedText.count <= parent.maxLength
        }
    }
}

// MARK: - Options sheet (gear on Players screen)

private enum PlayerOptionsLinks {
    /// Replace with your App Store support email before release.
    static let contactEmail = "support@example.com"
    static let privacyURL = URL(string: "https://www.verte-bro.com/privacy-policy")
    static let termsURL = URL(string: "https://www.verte-bro.com/terms-and-conditions")
}

struct PlayerOptionsSheet: View {
    @Binding var isPresented: Bool
    @State private var firebaseInstallationId: String = ""
    @State private var isLoadingFirebaseId = true
    @State private var didCopyUDID = false
    @State private var toastMessage = ""
    @State private var showToast = false

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                Text("Options")
                    .font(.evolventa(size: 22, weight: .bold))
                    .foregroundColor(.gameplayTitle)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                VStack(spacing: 10) {
                    optionRow(title: "Language", systemImage: "globe") {
                        openURLString(UIApplication.openSettingsURLString)
                    }
                    optionRow(title: "Contact Us", systemImage: "envelope") {
                        if let url = URL(string: "mailto:\(PlayerOptionsLinks.contactEmail)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    optionRow(title: "Privacy Policy", systemImage: "shield") {
                        if let url = PlayerOptionsLinks.privacyURL {
                            UIApplication.shared.open(url)
                        }
                    }
                    optionRow(title: "Terms & Conditions", systemImage: "doc.text") {
                        if let url = PlayerOptionsLinks.termsURL {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .padding(.horizontal, 20)

                firebaseInstallationIdRow

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
                        .background(Color.gameplayButtonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            loadFirebaseInstallationID()
        }
        .overlay(alignment: .topLeading) {
            if showToast {
                Text(toastMessage)
                    .font(.evolventa(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.82))
                    .clipShape(Capsule())
                    .padding(.top, 230)
                    .padding(.leading, 30)
                    .transition(.offset(y: -8).combined(with: .opacity))
            }
        }
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
    }

    private var firebaseInstallationIdRow: some View {
        let valueText: String = {
            if isLoadingFirebaseId { return "Loading…" }
            if firebaseInstallationId.isEmpty { return "Unavailable" }
            return firebaseInstallationId
        }()

        return Button(action: copyFirebaseInstallationID) {
            HStack(alignment: .center, spacing: 12) {
                Text("UDID:")
                    .font(.evolventa(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Text(valueText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: didCopyUDID ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.evolventa(size: 16, weight: .semibold))
                    .foregroundColor(didCopyUDID ? .green.opacity(0.9) : .white.opacity(0.55))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(OptionsRowButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func loadFirebaseInstallationID() {
        isLoadingFirebaseId = true
        Installations.installations().installationID { id, _ in
            DispatchQueue.main.async {
                if let id, !id.isEmpty {
                    firebaseInstallationId = id
                } else if let analyticsId = Analytics.appInstanceID(), !analyticsId.isEmpty {
                    firebaseInstallationId = analyticsId
                } else {
                    firebaseInstallationId = ""
                }
                isLoadingFirebaseId = false
            }
        }
    }

    private func copyFirebaseInstallationID() {
        guard !isLoadingFirebaseId else {
            showToast(message: "UDID is still loading. Try again in a moment.")
            HapticsManager.notification(.warning)
            return
        }
        guard !firebaseInstallationId.isEmpty else {
            showToast(message: "UDID is unavailable right now.")
            HapticsManager.notification(.warning)
            return
        }
        UIPasteboard.general.string = firebaseInstallationId
        didCopyUDID = UIPasteboard.general.string == firebaseInstallationId
        if didCopyUDID {
            showToast(message: "UDID copied")
            HapticsManager.impact(.light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                didCopyUDID = false
            }
        } else {
            showToast(message: "Could not copy UDID")
            HapticsManager.notification(.warning)
        }
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
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(OptionsRowButtonStyle())
    }

    private func openURLString(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    private func showToast(message: String) {
        toastMessage = message
        withAnimation(.easeOut(duration: 0.18)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.18)) {
                showToast = false
            }
        }
    }

    private struct OptionsRowButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(configuration.isPressed ? 0.55 : 0.0), lineWidth: 1.5)
                )
                .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
                .opacity(configuration.isPressed ? 0.68 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

struct PlayerRow: View {
    let name: String
    let avatarIndex: Int
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            PlayerAvatarThumbnailView(avatarIndex: avatarIndex, size: 44, cornerRadius: 22)

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
        .background(Color.gameplaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Player row") {
    VStack(spacing: 10) {
        PlayerRow(name: "Alex", avatarIndex: 0, canDelete: true, onDelete: {})
        PlayerRow(name: "Jordan", avatarIndex: 5, canDelete: true, onDelete: {})
        PlayerRow(name: "Sam", avatarIndex: 11, canDelete: false, onDelete: {})
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [Color(red: 0.45, green: 0.12, blue: 0.18), Color(red: 0.2, green: 0.05, blue: 0.12)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
