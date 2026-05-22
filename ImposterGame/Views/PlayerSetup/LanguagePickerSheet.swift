import SwiftUI
import UIKit

/// Renders flag emoji with a font that includes color emoji glyphs (custom app fonts break 🇺🇸).
private struct FlagEmojiLabel: UIViewRepresentable {
    let emoji: String
    var size: CGFloat = 28

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = .clear
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = emoji
        if let emojiFont = UIFont(name: "Apple Color Emoji", size: size) {
            label.font = emojiFont
        } else {
            label.font = .systemFont(ofSize: size)
        }
    }
}

/// Modal sheet for choosing the app language. Changes apply immediately (no restart).
struct LanguagePickerSheet: View {
    @Binding var isPresented: Bool

    @ObservedObject private var localization = LocalizationService.shared

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(
                    GridPatternView()
                        .opacity(0.1)
                )

            VStack(spacing: 0) {
                Text("language.sheet.title")
                    .font(.evolventa(size: 22, weight: .bold))
                    .foregroundColor(.gameplayTitle)
                    .padding(.top, 28)
                    .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(LocalizationService.supportedLocales) { locale in
                            languageRow(locale: locale)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                backButton
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .environment(\.locale, localization.locale)
    }

    private func languageRow(locale: SupportedLocale) -> some View {
        let isSelected = locale.code == localization.currentLocaleCode

        return Button(action: {
            HapticsManager.impact(.light)
            localization.selectLocale(code: locale.code)
        }) {
            HStack(spacing: 14) {
                FlagEmojiLabel(emoji: locale.flag, size: 30)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: locale.nativeName)
                        .font(.evolventa(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(verbatim: locale.englishName)
                        .font(.evolventa(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gameplayButtonPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var backButton: some View {
        Button(action: {
            HapticsManager.impact(.light)
            isPresented = false
        }) {
            Text("common.back")
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
