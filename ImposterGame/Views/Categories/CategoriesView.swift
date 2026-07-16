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
                            .font(.evolventa(size: 16))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.appSurface))
                            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
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
                            .font(.evolventa(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.appSurface))
                            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: Color.appAccent.opacity(0.45), radius: 12, x: 0, y: 6)
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

}

struct CategoryCard: View {
    let category: Category
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void

    private let iconSize: CGFloat = 76

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(verbatim: category.name)
                            .font(.evolventa(size: 21, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if isSelected && !isLocked {
                            selectedBadge
                        } else if isLocked {
                            proChip
                        }
                    }

                    Text(verbatim: category.description)
                        .font(.evolventa(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                categoryIcon
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.appAccent : Color.white.opacity(0.07),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: Color.appAccent.opacity(isSelected ? 0.25 : 0.0), radius: 20, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    /// Pink "selected" checkmark chip (mock 2c).
    private var selectedBadge: some View {
        Image(systemName: "checkmark")
            .font(.evolventa(size: 11, weight: .bold))
            .foregroundColor(.appTextOnAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.appAccent))
    }

    /// Locked "PRO" pill (mock 2c).
    private var proChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.evolventa(size: 10, weight: .bold))
            Text(verbatim: "PRO")
                .font(.evolventa(size: 11, weight: .bold))
        }
        .foregroundColor(.appAccentHigh)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.appSurface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if let iconImage = CategoryIconLoader.uiImage(for: category.icon) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.10))
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
            .frame(width: iconSize, height: iconSize)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .frame(width: iconSize, height: iconSize)
                .overlay(
                    Image(systemName: category.icon)
                        .font(.evolventa(size: 30, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
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
                            .fill(index == currentStep ? Color.appAccent : Color.white.opacity(0.35))
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
