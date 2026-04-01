import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var categories: [Category] = []
    @State private var selectedCategoryID: UUID?
    @State private var showInfoOverlay = false
    @State private var onboardingStep = 0

    private var selectedCategoryCount: Int {
        selectedCategoryID == nil ? 0 : 1
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
                    Button(action: { router.pop() }) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Categories")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        HapticsManager.impact(.light)
                        onboardingStep = 0
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showInfoOverlay = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Category list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            CategoryCard(
                                category: category,
                                isSelected: selectedCategoryID == category.id,
                                isLocked: index != 0,
                                onTap: {
                                    if index != 0 {
                                        HapticsManager.notification(.warning)
                                        return
                                    }
                                    HapticsManager.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategoryID = category.id
                                    }
                                    gameSession.selectedCategory = category
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }

                Button(action: {
                    guard selectedCategoryID != nil else {
                        HapticsManager.notification(.warning)
                        return
                    }
                    HapticsManager.impact(.medium)
                    router.navigate(to: .gameSettings)
                }) {
                    HStack(spacing: 14) {
                        Text("PLAY")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)

                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 1, height: 26)

                        Text("\(selectedCategoryCount) Category")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .opacity(selectedCategoryID == nil ? 0.85 : 1.0)
            }

            if showInfoOverlay {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.95)) {
                            showInfoOverlay = false
                        }
                    }

                CategoryInfoOverlay(
                    currentStep: $onboardingStep,
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.95)) {
                            showInfoOverlay = false
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 0)
                .padding(.bottom, 0)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            categories = CategoryLoader.loadCategories()
            if selectedCategoryID == nil, let first = categories.first {
                selectedCategoryID = first.id
                gameSession.selectedCategory = first
            }
        }
    }
}

struct CategoryCard: View {
    let category: Category
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(category.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    Text(category.description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Text(categoryEmoji)
                    .font(.system(size: 56))
                    .padding(.trailing, 2)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color(white: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .opacity(isLocked ? 0.78 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var categoryEmoji: String {
        switch category.name {
        case "Party Time":
            return "🍾🪩"
        case "Food":
            return "🥤🍣"
        case "Celebrities":
            return "⭐️🎤"
        case "Hobbies":
            return "📓🩰"
        case "Family":
            return "👨‍👩‍👧"
        case "School & College":
            return "🎓📚"
        case "Places":
            return "🗺️🏝️"
        case "Sports":
            return "⚽️🏀"
        case "Spicy":
            return "🌶️🔥"
        case "Movies & TV":
            return "🎬📺"
        case "Animals":
            return "🦊🐼"
        case "Work":
            return "💼📈"
        default:
            return "🎯✨"
        }
    }
}

struct CategoryInfoOverlay: View {
    @Binding var currentStep: Int
    let onClose: () -> Void

    private let steps: [CategoryInfoStep] = [
        CategoryInfoStep(
            title: "Choose Your Themes",
            subtitle: "Pick one or more themes to set the mood and match your vibe and party.",
            content: .emoji("🏟️ 🌶️ 🪩"),
            buttonTitle: "Next"
        ),
        CategoryInfoStep(
            title: "Drop a Clue",
            subtitle: "Give a clever hint or association. Clear for those in the know - confusing for the imposter.",
            content: .chips(["Yellow", "Monkey Snack", "Curved"], "🍌"),
            buttonTitle: "Next"
        ),
        CategoryInfoStep(
            title: "Check Your Role",
            subtitle: "Everyone sees the secret word... except the imposter - they only see their role. Their goal? Blend in.",
            content: .emoji("👤 👤 🕵️ 👤"),
            buttonTitle: "Next"
        ),
        CategoryInfoStep(
            title: "Time to Vote",
            subtitle: "Talk's over. Now vote to expose the imposter!",
            content: .voteBox,
            buttonTitle: "Got It!"
        )
    ]

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                Text(steps[currentStep].title)
                    .font(.system(size: 44, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .padding(.top, 42)

                Text(steps[currentStep].subtitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 14)

                contentView(for: steps[currentStep])
                    .padding(.top, 34)

                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.white : Color.white.opacity(0.35))
                            .frame(width: 9, height: 9)
                    }
                }
                .padding(.top, 26)

                Button(action: nextTapped) {
                    Text(steps[currentStep].buttonTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 30)
                .padding(.top, 32)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
            .background(LinearGradient.appRedGradient)
            .clipShape(RoundedRectangle(cornerRadius: 34))
            .overlay(
                RoundedRectangle(cornerRadius: 34)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func contentView(for step: CategoryInfoStep) -> some View {
        switch step.content {
        case .emoji(let text):
            Text(text)
                .font(.system(size: 60))
                .padding(.horizontal, 20)

        case .chips(let chips, let emoji):
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.16, green: 0.15, blue: 0.25))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            )
                    }
                }
                Text(emoji)
                    .font(.system(size: 76))
            }
            .padding(.horizontal, 20)

        case .voteBox:
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("✅  Guess right - you win")
                    Text("❌  Miss - imposter wins")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color(red: 0.16, green: 0.15, blue: 0.25))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                )

                Text("⚠️ If the imposter guesses the word before time runs out, they win instantly")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .padding(.horizontal, 30)
        }
    }

    private func nextTapped() {
        HapticsManager.impact(.light)
        if currentStep < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentStep += 1
            }
        } else {
            onClose()
        }
    }
}

struct CategoryInfoStep {
    let title: String
    let subtitle: String
    let content: CategoryInfoContent
    let buttonTitle: String
}

enum CategoryInfoContent {
    case emoji(String)
    case chips([String], String)
    case voteBox
}
