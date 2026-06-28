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
    @EnvironmentObject var localization: LocalizationService
    @State private var categories: [Category] = []
    @State private var selectedCategoryID: UUID?
    @State private var showInfoOverlay = false
    @State private var onboardingStep = 0
    @State private var pushPermissionTask: Task<Void, Never>?

    private static let categoryBackgroundPalette: [LinearGradient] = [
        LinearGradient(
            colors: [Color(red: 0.42, green: 0.18, blue: 0.72), Color(red: 0.22, green: 0.10, blue: 0.48)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.92, green: 0.34, blue: 0.18), Color(red: 0.62, green: 0.14, blue: 0.22)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.48, blue: 0.78), Color(red: 0.06, green: 0.26, blue: 0.58)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.18, green: 0.62, blue: 0.38), Color(red: 0.08, green: 0.36, blue: 0.28)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.88, green: 0.22, blue: 0.52), Color(red: 0.52, green: 0.10, blue: 0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.96, green: 0.58, blue: 0.10), Color(red: 0.72, green: 0.28, blue: 0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.28, green: 0.36, blue: 0.92), Color(red: 0.14, green: 0.18, blue: 0.62)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            colors: [Color(red: 0.20, green: 0.72, blue: 0.78), Color(red: 0.10, green: 0.42, blue: 0.58)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    ]

    private var selectedCategoryCount: Int {
        selectedCategoryID == nil ? 0 : 1
    }

    private var selectionCountLabel: String {
        let wordKey = selectedCategoryCount == 1
            ? "categories.selection_count_singular"
            : "categories.selection_count_plural"
        return "\(selectedCategoryCount) \(localization.localized(wordKey))"
    }

    var body: some View {
        let _ = localization.currentLocaleCode
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

                    Text("categories.title")
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
                .padding(.top, 12)
                .padding(.bottom, 14)

                // Category list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
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
                    .padding(.bottom, 110)
                }
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
        .safeAreaInset(edge: .bottom) {
            Group {
                if showInfoOverlay {
                    Color.clear.frame(height: 0)
                } else {
                    Button(action: {
                        guard selectedCategoryID != nil else {
                            HapticsManager.notification(.warning)
                            return
                        }
                        HapticsManager.impact(.medium)
                        router.navigate(to: .gameSettings)
                    }) {
                        HStack(spacing: 14) {
                            Text("categories.play")
                                .font(.evolventa(size: 20, weight: .bold))
                                .foregroundColor(.appTextOnAccent)

                            Rectangle()
                                .fill(Color.appTextOnAccent.opacity(0.25))
                                .frame(width: 1, height: 26)

                            Text(selectionCountLabel)
                                .font(.evolventa(size: 20, weight: .semibold))
                                .foregroundColor(.appTextOnAccent.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gameplayButtonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                    .opacity(selectedCategoryID == nil ? 0.85 : 1.0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .onAppear {
            reloadCategories()
            schedulePushPermissionPromptIfNeeded()
        }
        .onDisappear {
            pushPermissionTask?.cancel()
            pushPermissionTask = nil
        }
        .onChange(of: localization.currentLocaleCode) { _ in
            reloadCategories()
        }
        .onChange(of: subscriptionManager.isPremium) { _ in
            restoreSelection()
        }
    }

    private func reloadCategories() {
        categories = CategoryLoader.loadCategories()
        restoreSelection()
    }

    private func schedulePushPermissionPromptIfNeeded() {
        pushPermissionTask?.cancel()
        pushPermissionTask = Task {
            guard await PushNotificationService.shouldRequestPermissionOnCategories() else { return }
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }

            let shouldSkip = await MainActor.run { showInfoOverlay }
            guard !shouldSkip else { return }

            let context = PushNotificationService.permissionAnalyticsContext()
            PushNotificationService.markPermissionRequestAttempted(context: context)
            PushNotificationService.logPromptShown(context: context)
            await PushNotificationService.requestPermission(context: context)
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

    private let iconSize: CGFloat = 96

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                categoryIcon

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(verbatim: category.name)
                            .font(.evolventa(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.evolventa(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    Text(verbatim: category.description)
                        .font(.evolventa(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.18),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if let iconImage = CategoryIconLoader.uiImage(for: category.icon) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.14))
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
            .frame(width: iconSize, height: iconSize)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.22))
                .frame(width: iconSize, height: iconSize)
                .overlay(
                    Image(systemName: category.icon)
                        .font(.evolventa(size: 34, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        }
    }

}

struct CategoryInfoOverlay: View {
    @Binding var currentStep: Int
    let onClose: () -> Void

    private let steps: [CategoryInfoStep] = [
        CategoryInfoStep(
            titleKey: "categories.info.step1_title",
            subtitleKey: "categories.info.step1_subtitle",
            content: .emoji("🏟️ 🌶️ 🪩"),
            buttonTitleKey: "common.next"
        ),
        CategoryInfoStep(
            titleKey: "categories.info.step2_title",
            subtitleKey: "categories.info.step2_subtitle",
            content: .chips(["Yellow", "Monkey Snack", "Curved"], "🍌"),
            buttonTitleKey: "common.next"
        ),
        CategoryInfoStep(
            titleKey: "categories.info.step3_title",
            subtitleKey: "categories.info.step3_subtitle",
            content: .emoji("👤 👤 🕵️ 👤"),
            buttonTitleKey: "common.next"
        ),
        CategoryInfoStep(
            titleKey: "categories.info.step4_title",
            subtitleKey: "categories.info.step4_subtitle",
            content: .voteBox,
            buttonTitleKey: "common.got_it"
        )
    ]

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                Text(steps[currentStep].titleKey)
                    .font(.evolventa(size: 44, weight: .bold))
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gameplayTitle)
                    .padding(.horizontal, 22)
                    .padding(.top, 42)

                Text(steps[currentStep].subtitleKey)
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
                    Text(steps[currentStep].buttonTitleKey)
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
            Text(verbatim: text)
                .font(.system(size: 60, weight: .heavy))
                .padding(.horizontal, 20)

        case .chips(let chips, let emoji):
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(chips, id: \.self) { chip in
                        Text(verbatim: chip)
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
                Text(verbatim: emoji)
                    .font(.system(size: 76))
            }
            .padding(.horizontal, 20)

        case .voteBox:
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("categories.info.vote_win")
                    Text("categories.info.vote_lose")
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

                Text("categories.info.instant_win_warning")
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
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let content: CategoryInfoContent
    let buttonTitleKey: LocalizedStringKey
}

enum CategoryInfoContent {
    case emoji(String)
    case chips([String], String)
    case voteBox
}
