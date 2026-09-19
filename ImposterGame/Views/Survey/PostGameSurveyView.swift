import SwiftUI

/// One-time pulse survey shown after the user's 2nd completed game, gauging session quality
/// and collecting optional free-text feedback and an email for follow-up. Presented as a
/// `.sheet` sized to its own content, closed only by its X. It takes the result screen for its
/// round, which pushes that round's post-game offer to the following "Play Again" tap.
struct PostGameSurveyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .choice
    @State private var selectedChoice: SurveyService.Choice?
    @State private var openText = ""
    @State private var email = ""
    /// Drives the sheet's detent so it fits whatever the current step needs - the choice step is
    /// three buttons tall, the details step several times that, and a fixed detent would strand
    /// one of them under a screen of dead space.
    @State private var contentHeight: CGFloat = 0
    private let documentID = UUID().uuidString

    private enum Step {
        case choice
        case details
    }

    private let options: [(SurveyService.Choice, LocalizedStringKey)] = [
        (.everyone, "survey.option_everyone"),
        (.some, "survey.option_some"),
        (.fellFlat, "survey.option_fell_flat")
    ]

    private var detailsPromptKey: LocalizedStringKey {
        selectedChoice == .everyone ? "survey.prompt_everyone" : "survey.prompt_negative"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient.appPurpleGradient
                .ignoresSafeArea()
                .overlay(
                    GridPatternView(lineColor: .white.opacity(0.14))
                        .opacity(0.5)
                )

            surveyScrollView

            closeButton
        }
        // Falls back to `.medium` for the single frame before the content reports its height -
        // a `.height(0)` detent would collapse the sheet to nothing on first presentation.
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight)] : [.medium])
        .presentationDragIndicator(.hidden)
        // The X is the only way out: one detent means nothing to drag between, and swipe-to-dismiss
        // is off, so the survey can't be flicked away by accident mid-answer.
        .interactiveDismissDisabled()
        .onAppear {
            SurveyService.markShown()
        }
    }

    private var closeButton: some View {
        Button(action: handleSkip) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
        .padding(.top, 14)
        .padding(.trailing, 16)
    }

    /// Disables rubber-band bounce when content is shorter than the sheet: without it, the
    /// ScrollView's overscroll and the sheet's own drag-to-resize gesture fight over every tap
    /// near the top of the content, producing a visible jitter on each interaction.
    ///
    /// Still a ScrollView rather than a plain VStack because the detent is capped: a long
    /// localization, or the keyboard on the details step, can outgrow the room the sheet gets.
    private var surveyScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                switch step {
                case .choice:
                    choiceStep
                case .details:
                    detailsStep
                }
            }
            .padding(.horizontal, 20)
            // Clears the close button, which floats over this content in the top-trailing corner.
            .padding(.top, 52)
            .padding(.bottom, 24)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SurveyContentHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
        }
        .survey_scrollBounceIfAvailable()
        .onPreferenceChange(SurveyContentHeightKey.self) { height in
            guard height > 0 else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                contentHeight = min(height, UIScreen.main.bounds.height * 0.9)
            }
        }
    }

    private var choiceStep: some View {
        VStack(spacing: 18) {
            Text("survey.question_title")
                .font(.antropicSans(size: 24, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                ForEach(options, id: \.0) { choice, titleKey in
                    Button {
                        selectChoice(choice)
                    } label: {
                        Text(titleKey)
                            .font(.antropicSerif(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 18)
                            .background(Color.appSurface2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private var detailsStep: some View {
        VStack(spacing: 18) {
            Text(detailsPromptKey)
                .font(.antropicSans(size: 22, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            TextEditor(text: $openText)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
                .font(.antropicSerif(size: 15, weight: .medium))
                .frame(height: 100)
                .padding(10)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 8) {
                Text("survey.email_placeholder")
                    .font(.antropicSerif(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))

                TextField("", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(.white)
                    .font(.antropicSerif(size: 15, weight: .medium))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.appSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }

            Button(action: handleSubmit) {
                Text("survey.submit")
                    .font(.antropicSans(size: 16, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button(action: handleSkip) {
                Text("survey.skip")
                    .font(.antropicSerif(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    private func selectChoice(_ choice: SurveyService.Choice) {
        HapticsManager.selection()
        selectedChoice = choice
        SurveyService.submitChoice(choice, documentID: documentID)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            step = .details
        }
    }

    private func handleSubmit() {
        HapticsManager.impact(.medium)
        SurveyService.submitDetails(openText: openText, email: email, documentID: documentID)
        dismiss()
    }

    private func handleSkip() {
        dismiss()
    }
}

private struct SurveyContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    @ViewBuilder
    func survey_scrollBounceIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}
