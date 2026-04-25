import SwiftUI

/// Modal sheet that lets the user manually override the app's language.
///
/// iOS resolves the language at process launch from `AppleLanguages` in
/// UserDefaults, so we apply the override and prompt the user to restart.
/// The "Restart Now" button calls `LocalizationService.triggerRelaunch()`
/// which exits the app cleanly. iOS will relaunch it from the home screen
/// — at which point all `.lproj` resources resolve to the new locale.
struct LanguagePickerSheet: View {
    @Binding var isPresented: Bool

    @StateObject private var localization = LocalizationService.shared
    @State private var pendingLocaleCode: String?
    @State private var showRestartPrompt = false

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(LocalizationService.supportedLocales) { locale in
                            languageRow(locale: locale)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }

                closeButton
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(
            "Restart required",
            isPresented: $showRestartPrompt,
            actions: {
                Button("Restart Now", role: .destructive) {
                    if let code = pendingLocaleCode {
                        localization.selectLocale(code: code)
                    }
                    localization.triggerRelaunch()
                }
                Button("Later", role: .cancel) {
                    if let code = pendingLocaleCode {
                        localization.selectLocale(code: code)
                    }
                    isPresented = false
                }
            },
            message: {
                Text("The new language will appear after the app restarts.")
            }
        )
    }

    private var header: some View {
        VStack(spacing: 0) {
            Text("Language Setting")
                .font(.evolventa(size: 22, weight: .bold))
                .foregroundColor(.gameplayTitle)
        }
        .padding(.top, 28)
        .padding(.bottom, 18)
    }

    private func languageRow(locale: SupportedLocale) -> some View {
        let isSelected = locale.code == localization.currentLocaleCode

        return Button(action: {
            HapticsManager.impact(.light)
            handleSelection(locale: locale)
        }) {
            HStack(spacing: 14) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(locale.nativeName)
                        .font(.evolventa(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(locale.englishName)
                        .font(.evolventa(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer(minLength: 12)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.gameplayButtonPrimary)
                        .shadow(color: Color.gameplayButtonPrimary.opacity(0.45), radius: 8, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.12 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isSelected ? 0.06 : 0.02),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.gameplayButtonPrimary.opacity(0.65) : Color.white.opacity(0.10),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color.gameplayButtonPrimary.opacity(0.22) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
    }

    private var closeButton: some View {
        Button(action: {
            HapticsManager.impact(.light)
            isPresented = false
        }) {
            Text(LocalizedStringKey("common.close"))
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

    private func handleSelection(locale: SupportedLocale) {
        guard locale.code != localization.currentLocaleCode else { return }
        pendingLocaleCode = locale.code
        showRestartPrompt = true
    }
}
