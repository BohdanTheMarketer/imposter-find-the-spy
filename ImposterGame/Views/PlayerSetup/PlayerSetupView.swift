import FirebaseInstallations
import SwiftUI
import UIKit
import Combine

struct PlayerEntry: Identifiable {
    let id = UUID()
    var name: String
    var avatarIndex: Int
}

struct PlayerSetupView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @EnvironmentObject var localization: LocalizationService
    @State private var players: [PlayerEntry] = []
    @State private var newPlayerName: String = ""
    @State private var showOptionsMenu = false
    /// Bumped to programmatically focus the UIKit name field (see `PlayerNameEntryField`).
    @State private var nameFieldFocusToken = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var listScrollProxy: ScrollViewProxy?
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
        let wordKey = players.count == 1
            ? "player_setup.player_count_singular"
            : "player_setup.player_count_plural"
        return "\(players.count) \(localization.localized(wordKey))"
    }

    private var nameFieldPlaceholder: String {
        localization.localized("player_setup.name_placeholder")
    }

    @ViewBuilder
    private var nameInputSection: some View {
        if players.count < maxPlayers {
            HStack(spacing: 12) {
                PlayerNameEntryField(
                    text: $newPlayerName,
                    placeholder: nameFieldPlaceholder,
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
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

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
                    AnalyticsService.logPlayerSetupContinueTapped(playerCount: validPlayerCount)
                    PlayerSetupKeyboard.dismiss()
                    setupPlayers()
                    // Paywall decision already happened right after onboarding, before this screen.
                    router.navigate(to: .categories)
                }) {
                    HStack(spacing: 14) {
                        Text("player_setup.continue")
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.appTextOnAccent)
                        Rectangle()
                            .fill(Color.appTextOnAccent.opacity(0.25))
                            .frame(width: 1, height: 26)
                        Text(playerCountLabel)
                            .font(.evolventa(size: 20, weight: .semibold))
                            .foregroundColor(.appTextOnAccent.opacity(0.85))
                    }
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
                .opacity(canContinue ? 1.0 : 0.85)
            } else {
                Text("player_setup.minimum_players_hint")
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
        let _ = localization.currentLocaleCode

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
                    Text("player_setup.title")
                        .font(.evolventa(size: 28, weight: .bold))
                        .foregroundColor(.gameplayTitle)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button(action: {
                        HapticsManager.impact(.light)
                        AnalyticsService.logPlayerSetupOptionsOpened()
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
                            ForEach(players) { entry in
                                PlayerRow(
                                    name: entry.name,
                                    avatarIndex: entry.avatarIndex,
                                    canDelete: true,
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            players.removeAll { $0.id == entry.id }
                                        }
                                        HapticsManager.impact(.light)
                                        AnalyticsService.logPlayerRemoved(playerCount: players.count)
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
                        listScrollProxy = proxy
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

    private func scrollInputRowToVisible() {
        guard players.count < maxPlayers, let proxy = listScrollProxy else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(inputRowScrollId, anchor: .bottom)
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
            players.append(
                PlayerEntry(
                    name: uniqueName,
                    avatarIndex: nextRandomAvatarIndex()
                )
            )
        }
        newPlayerName = ""
        AnalyticsService.logPlayerAdded(playerCount: players.count)
        scrollInputRowToVisible()
        HapticsManager.impact(.light)
    }

    /// Prefer unused avatars first so early players look distinct.
    private func nextRandomAvatarIndex() -> Int {
        let allIndices = Set(0..<PlayerProfiles.count)
        let usedIndices = Set(players.map(\.avatarIndex))
        let available = Array(allIndices.subtracting(usedIndices))

        if let uniquePick = available.randomElement() {
            return uniquePick
        }

        return Int.random(in: 0..<PlayerProfiles.count)
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
        if overlap > 0 {
            scrollInputRowToVisible()
        }
    }

    private func setupPlayers() {
        gameSession.players = players.map { entry in
            Player(name: entry.name, avatarIndex: entry.avatarIndex)
        }
    }

    /// `PlayerSetupView` keeps its own list until Continue; when returning from Categories or after Play Again, repopulate from the session.
    private func syncLocalPlayersFromSession() {
        guard !gameSession.players.isEmpty else { return }
        players = gameSession.players.map { PlayerEntry(name: $0.name, avatarIndex: $0.avatarIndex) }
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
        tf.font = UIFont(name: "Inter-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
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
        if context.coordinator.lastPlaceholder != placeholder {
            context.coordinator.lastPlaceholder = placeholder
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.45)]
            )
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
        var lastPlaceholder: String = ""

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
    @State private var installationId: String = ""
    @State private var isLoadingInstallationId = true
    @State private var didCopyInstallationId = false
    @State private var toastMessage = ""
    @State private var showToast = false
    @State private var showLanguagePicker = false

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                Text("player_setup.options_title")
                    .font(.evolventa(size: 22, weight: .bold))
                    .foregroundColor(.gameplayTitle)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                VStack(spacing: 10) {
                    optionRow(titleKey: "player_setup.options_language", systemImage: "globe") {
                        showLanguagePicker = true
                    }
                    optionRow(titleKey: "player_setup.options_contact", systemImage: "envelope") {
                        if let url = URL(string: "mailto:\(PlayerOptionsLinks.contactEmail)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    optionRow(titleKey: "legal.privacy_policy", systemImage: "shield") {
                        if let url = PlayerOptionsLinks.privacyURL {
                            UIApplication.shared.open(url)
                        }
                    }
                    optionRow(titleKey: "legal.terms", systemImage: "doc.text") {
                        if let url = PlayerOptionsLinks.termsURL {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                .padding(.horizontal, 20)

                installationIdRow

                Spacer(minLength: 12)

                Button(action: {
                    HapticsManager.impact(.light)
                    isPresented = false
                }) {
                    Text("common.close")
                        .font(.evolventa(size: 18, weight: .bold))
                        .foregroundColor(.appTextOnAccent)
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
            loadInstallationId()
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(isPresented: $showLanguagePicker)
        }
        .overlay(alignment: .topLeading) {
            if showToast {
                Text(verbatim: toastMessage)
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

    private var installationIdRow: some View {
        let valueText: String = {
            if isLoadingInstallationId { return String(localized: "player_setup.install_id_loading") }
            if installationId.isEmpty { return String(localized: "player_setup.install_id_unavailable") }
            return installationId
        }()

        return Button(action: copyInstallationId) {
            HStack(alignment: .center, spacing: 12) {
                Text("player_setup.install_id_label")
                    .font(.evolventa(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Text(verbatim: valueText)
                    .font(.evolventa(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: didCopyInstallationId ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.evolventa(size: 16, weight: .semibold))
                    .foregroundColor(didCopyInstallationId ? .green.opacity(0.9) : .white.opacity(0.55))
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

    private func loadInstallationId() {
        isLoadingInstallationId = true
        Installations.installations().installationID { id, _ in
            DispatchQueue.main.async {
                installationId = id ?? ""
                isLoadingInstallationId = false
            }
        }
    }

    private func copyInstallationId() {
        guard !isLoadingInstallationId else {
            showToast(message: String(localized: "player_setup.install_id_toast_loading"))
            HapticsManager.notification(.warning)
            return
        }
        guard !installationId.isEmpty else {
            showToast(message: String(localized: "player_setup.install_id_toast_unavailable"))
            HapticsManager.notification(.warning)
            return
        }
        UIPasteboard.general.string = installationId
        didCopyInstallationId = UIPasteboard.general.string == installationId
        if didCopyInstallationId {
            showToast(message: String(localized: "player_setup.install_id_toast_copied"))
            HapticsManager.impact(.light)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                didCopyInstallationId = false
            }
        } else {
            showToast(message: String(localized: "player_setup.install_id_toast_copy_failed"))
            HapticsManager.notification(.warning)
        }
    }

    private func optionRow(titleKey: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticsManager.impact(.light)
            action()
        }) {
            HStack {
                Text(titleKey)
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

            Text(verbatim: name)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
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
