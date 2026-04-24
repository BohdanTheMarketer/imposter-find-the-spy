import SwiftUI
import UIKit

private enum CategoryIconLoader {
    private static let fileNameByIcon: [String: String] = [
        "party.popper": "category_party_popper",
        "fork.knife": "category_fork_knife",
        "star.fill": "category_star_fill",
        "paintpalette.fill": "category_paintpalette_fill",
        "house.fill": "category_house_fill",
        "book.fill": "category_book_fill",
        "flame.fill": "category_flame_fill",
        "sportscourt.fill": "category_sportscourt_fill",
        "airplane": "category_airplane",
        "briefcase.fill": "category_briefcase_fill",
        "film.fill": "category_film_fill",
        "bag.fill": "category_bag_fill",
        "desktopcomputer": "category_desktopcomputer",
        "bolt.fill": "category_bolt_fill",
        "music.note": "category_music_note",
        "map.fill": "category_map_fill"
    ]

    static func uiImage(for icon: String) -> UIImage? {
        guard let fileName = fileNameByIcon[icon] else { return nil }
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: "png") else { return nil }
        return UIImage(contentsOfFile: filePath)
    }
}

struct CategoriesView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var categories: [Category] = []
    @State private var selectedCategoryID: UUID?
    @State private var showInfoOverlay = false
    @State private var onboardingStep = 0

    private static let categoryBackgroundPalette: [LinearGradient] = [
        LinearGradient(
            colors: [Color(red: 0.15, green: 0.17, blue: 0.24), Color(red: 0.09, green: 0.11, blue: 0.17)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.20, green: 0.12, blue: 0.34), Color(red: 0.11, green: 0.10, blue: 0.24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.06, green: 0.20, blue: 0.35), Color(red: 0.05, green: 0.12, blue: 0.23)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.22, green: 0.13, blue: 0.17), Color(red: 0.11, green: 0.08, blue: 0.13)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.14, green: 0.15, blue: 0.25), Color(red: 0.08, green: 0.09, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.18, green: 0.21, blue: 0.14), Color(red: 0.09, green: 0.12, blue: 0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    ]

    private var selectedCategoryCount: Int {
        selectedCategoryID == nil ? 0 : 1
    }

    var body: some View {
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
                    Button(action: { router.pop() }) {
                        Image(systemName: "person.2.fill")
                            .font(.evolventa(size: 18))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Categories")
                        .font(.evolventa(size: 28, weight: .bold))
                        .foregroundColor(.gameplayTitle)

                    Spacer()

                    Button(action: {
                        HapticsManager.impact(.light)
                        onboardingStep = 0
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showInfoOverlay = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.evolventa(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Category list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(categories, id: \.id) { category in
                            let isLocked = category.isPremium && !subscriptionManager.isPremium
                            CategoryCard(
                                category: category,
                                isSelected: selectedCategoryID == category.id,
                                isLocked: isLocked,
                                background: backgroundForCategory(category, in: categories),
                                onTap: {
                                    if isLocked {
                                        HapticsManager.notification(.warning)
                                        router.navigate(to: .categoryPaywall)
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
                        Text("Play")
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.appTextOnAccent)

                        Rectangle()
                            .fill(Color.appTextOnAccent.opacity(0.25))
                            .frame(width: 1, height: 26)

                        Text("\(selectedCategoryCount) Category")
                            .font(.evolventa(size: 20, weight: .semibold))
                            .foregroundColor(.appTextOnAccent.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.gameplayButtonPrimary)
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
            restoreSelection()
        }
        .onChange(of: subscriptionManager.isPremium) { _ in
            restoreSelection()
        }
    }

    private func restoreSelection() {
        guard !categories.isEmpty else {
            selectedCategoryID = nil
            gameSession.selectedCategory = nil
            return
        }

        if let selectedCategoryID,
           let selectedCategory = categories.first(where: { $0.id == selectedCategoryID }) {
            gameSession.selectedCategory = selectedCategory
            return
        }

        if let previousCategory = gameSession.selectedCategory,
           let restoredCategory = categories.first(where: { $0.name == previousCategory.name }) {
            selectedCategoryID = restoredCategory.id
            gameSession.selectedCategory = restoredCategory
            return
        }

        if let firstCategory = categories.first(where: { !($0.isPremium && !subscriptionManager.isPremium) }) {
            selectedCategoryID = firstCategory.id
            gameSession.selectedCategory = firstCategory
        } else {
            selectedCategoryID = nil
            gameSession.selectedCategory = nil
        }
    }

    private func backgroundForCategory(_ category: Category, in allCategories: [Category]) -> LinearGradient {
        let paletteCount = Self.categoryBackgroundPalette.count
        guard paletteCount > 0 else {
            return LinearGradient(colors: [.black, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        guard let currentIndex = allCategories.firstIndex(where: { $0.id == category.id }) else {
            let fallback = deterministicPaletteIndex(for: category.name, paletteCount: paletteCount)
            return Self.categoryBackgroundPalette[fallback]
        }

        var paletteIndex = deterministicPaletteIndex(for: category.name, paletteCount: paletteCount)
        if currentIndex > 0 {
            let previousName = allCategories[currentIndex - 1].name
            let previousIndex = deterministicPaletteIndex(for: previousName, paletteCount: paletteCount)
            if previousIndex == paletteIndex {
                paletteIndex = (paletteIndex + 1) % paletteCount
            }
        }

        return Self.categoryBackgroundPalette[paletteIndex]
    }

    private func deterministicPaletteIndex(for key: String, paletteCount: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(key.lowercased())
        let value = hasher.finalize()
        return Int(UInt(bitPattern: value) % UInt(paletteCount))
    }
}

struct CategoryCard: View {
    let category: Category
    let isSelected: Bool
    let isLocked: Bool
    let background: LinearGradient
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                categoryIcon

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(category.name)
                            .font(.evolventa(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.evolventa(size: 13, weight: .semibold))
                                .foregroundColor(.gameplayButtonPrimary)
                        }
                    }

                    Text(category.description)
                        .font(.evolventa(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(nil)
                        .minimumScaleFactor(0.9)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(isSelected ? Color.white.opacity(0.85) : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
            .opacity(1.0)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if let iconImage = CategoryIconLoader.uiImage(for: category.icon) {
            Image(uiImage: iconImage)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        } else {
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 76, height: 76)
                .overlay(
                    Image(systemName: category.icon)
                        .font(.evolventa(size: 30, weight: .bold))
                        .foregroundColor(.white.opacity(0.92))
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
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
                    .font(.evolventa(size: 44, weight: .bold))
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gameplayTitle)
                    .padding(.horizontal, 22)
                    .padding(.top, 42)

                Text(steps[currentStep].subtitle)
                    .font(.evolventa(size: 17, weight: .semibold))
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
                        .font(.evolventa(size: 20, weight: .bold))
                        .foregroundColor(.appTextOnAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gameplayButtonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .padding(.horizontal, 30)
                .padding(.top, 32)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
            .background(LinearGradient.gameplayBackground)
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
                .font(.system(size: 60, weight: .heavy))
                .padding(.horizontal, 20)

        case .chips(let chips, let emoji):
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.evolventa(size: 20, weight: .medium))
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
                .font(.evolventa(size: 18, weight: .semibold))
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
                    .font(.evolventa(size: 16, weight: .semibold))
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
