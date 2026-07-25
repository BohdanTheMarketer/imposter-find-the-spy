import SwiftUI

/// Prompt → progress bar → generated pack flow for AI custom word packs (Categories screen entry point).
struct CustomWordPackGeneratorView: View {
    @EnvironmentObject var router: AppRouter
    @ObservedObject private var store = CustomWordPackStore.shared
    @FocusState private var isPromptFocused: Bool

    @State private var prompt: String = ""
    @State private var isGenerating = false
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var generatedCategory: Category?
    @State private var progressTask: Task<Void, Never>?

    private var canSubmit: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating && store.canCreateMore
    }

    var body: some View {
        ZStack {
            LinearGradient.gameplayBackground
                .ignoresSafeArea()
                .overlay(GridPatternView().opacity(0.1))

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let generatedCategory {
                            successCard(for: generatedCategory)
                        } else {
                            promptCard
                            if isGenerating {
                                progressCard
                            }
                            if let errorMessage {
                                errorBanner(errorMessage)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            progressTask?.cancel()
        }
        .onAppear {
            AnalyticsService.logCustomPackCreateOpened(existingPackCount: store.packs.count)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { router.pop() }) {
                Image(systemName: "chevron.left")
                    .font(.evolventa(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.appSurface))
                    .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
            }

            Spacer()

            Text("custom_pack.title")
                .font(.evolventa(size: 20, weight: .bold))
                .foregroundColor(.gameplayTitle)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: - Prompt input

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.appAccentHigh)
                Text("custom_pack.prompt_label")
                    .font(.evolventa(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            ZStack(alignment: .topLeading) {
                if prompt.isEmpty {
                    Text("custom_pack.prompt_placeholder")
                        .font(.evolventa(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $prompt)
                    .focused($isPromptFocused)
                    .font(.evolventa(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(height: 110)
                    .tint(.appAccent)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appSurface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPromptFocused ? Color.appAccent : Color.white.opacity(0.10), lineWidth: 1.5)
            )
            .disabled(isGenerating)

            Text(remainingSlotsLabel)
                .font(.evolventa(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            Button(action: startGeneration) {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.evolventa(size: 16, weight: .bold))
                    Text("custom_pack.generate_button")
                        .font(.evolventa(size: 18, weight: .bold))
                }
                .foregroundColor(.appTextOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.gameplayButtonPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 27))
                .overlay(
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: Color.appAccent.opacity(canSubmit ? 0.45 : 0), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1.0 : 0.5)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appSurface))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var remainingSlotsLabel: String {
        String(format: String(localized: "custom_pack.remaining_slots_format"), store.remainingSlots, CustomWordPackStore.maxPackCount)
    }

    // MARK: - Progress

    private var progressCard: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.appAccent)
                .frame(height: 6)

            Text("custom_pack.generating")
                .font(.evolventa(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.appSurface))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.2), value: isGenerating)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.revealOrange)
            Text(message)
                .font(.evolventa(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.appSurface2))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.revealOrange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Success

    private func successCard(for category: Category) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.appAccent)
            }
            .padding(.top, 20)

            Text("custom_pack.success_title")
                .font(.evolventa(size: 24, weight: .bold))
                .foregroundColor(.white)

            CategoryCard(category: category, isSelected: false, isLocked: false, onTap: {})
                .allowsHitTesting(false)

            Text(String(format: String(localized: "custom_pack.word_count_format"), category.words.count))
                .font(.evolventa(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))

            Button(action: { router.pop() }) {
                Text("custom_pack.done_button")
                    .font(.evolventa(size: 18, weight: .bold))
                    .foregroundColor(.appTextOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.gameplayButtonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 27))
                    .overlay(
                        RoundedRectangle(cornerRadius: 27)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.appAccent.opacity(0.45), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    // MARK: - Generation

    private func startGeneration() {
        guard canSubmit else { return }
        guard store.canCreateMore else {
            errorMessage = String(localized: "categories.custom_pack_limit_reached")
            AnalyticsService.logCustomPackLimitReached()
            return
        }

        HapticsManager.impact(.medium)
        isPromptFocused = false
        errorMessage = nil
        isGenerating = true
        progress = 0.05
        AnalyticsService.logCustomPackGenerateStarted(promptLength: prompt.trimmingCharacters(in: .whitespacesAndNewlines).count)

        progressTask?.cancel()
        progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 220_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    if progress < 0.9 {
                        progress = min(0.9, progress + Double.random(in: 0.03...0.09))
                    }
                }
            }
        }

        let submittedPrompt = prompt

        Task {
            do {
                let category = try await OpenAIWordPackService.generatePack(prompt: submittedPrompt)
                progressTask?.cancel()
                await MainActor.run {
                    progress = 1.0
                }
                let added = store.add(category)
                await MainActor.run {
                    isGenerating = false
                    if added, let stored = store.packs.first {
                        HapticsManager.notification(.success)
                        AnalyticsService.logCustomPackGenerateSucceeded(
                            categoryName: stored.name,
                            wordCount: stored.words.count,
                            totalPackCount: store.packs.count
                        )
                        withAnimation(.easeInOut(duration: 0.25)) {
                            generatedCategory = stored
                        }
                    } else {
                        HapticsManager.notification(.warning)
                        errorMessage = String(localized: "categories.custom_pack_limit_reached")
                        AnalyticsService.logCustomPackLimitReached()
                    }
                }
            } catch {
                progressTask?.cancel()
                await MainActor.run {
                    isGenerating = false
                    progress = 0
                    HapticsManager.notification(.error)
                    let message = (error as? LocalizedError)?.errorDescription
                        ?? String(localized: "custom_pack.error_generation_failed")
                    errorMessage = message
                    AnalyticsService.logCustomPackGenerateFailed(reason: "\(error)")
                }
            }
        }
    }
}
