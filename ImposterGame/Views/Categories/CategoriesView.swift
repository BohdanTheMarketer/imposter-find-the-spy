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
    @ObservedObject private var customPackStore = CustomWordPackStore.shared
    @State private var categories: [Category] = []
    @State private var selectedCategoryID: UUID?
    @State private var showInfoOverlay = false
    @State private var onboardingStep = 0
    @State private var pushPermissionTask: Task<Void, Never>?
    @State private var pendingDeleteCategory: Category?

    private var allSelectableCategories: [Category] {
        categories + customPackStore.packs
    }

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
                        AnalyticsService.logCategoryInfoOpened()
                        AnalyticsService.logCategoryInfoStepViewed(stepIndex: 0)
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
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            let isLocked = category.isPremium && !subscriptionManager.isPremium
                            CategoryCard(
                                category: category,
                                isSelected: selectedCategoryID == category.id,
                                isLocked: isLocked,
                                onTap: {
                                    if isLocked {
                                        HapticsManager.notification(.warning)
                                        AnalyticsService.logCategoryLockedTapped(categoryName: category.name)
                                        router.navigate(to: .categoryPaywall)
                                        return
                                    }
                                    HapticsManager.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategoryID = category.id
                                    }
                                    gameSession.selectedCategory = category
                                    AnalyticsService.logCategorySelected(categoryName: category.name, isPremium: category.isPremium)
                                }
                            )

                            // Promo banner as the 4th list item, nudging non-premium users toward the paywall.
                            if index == 2 && !subscriptionManager.isPremium {
                                PremiumPromoBannerCard(action: {
                                    HapticsManager.impact(.light)
                                    AnalyticsService.logPremiumBannerTapped()
                                    router.navigate(to: .categoryPaywall)
                                })
                            }
                        }

                        customPacksSection
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
                        AnalyticsService.logCategoriesPlayTapped(
                            categoryName: gameSession.selectedCategory?.name ?? "unknown",
                            playerCount: gameSession.players.count
                        )
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
        .alert(
            String(localized: "custom_pack.delete_confirm_title"),
            isPresented: Binding(
                get: { pendingDeleteCategory != nil },
                set: { if !$0 { pendingDeleteCategory = nil } }
            ),
            presenting: pendingDeleteCategory
        ) { category in
            Button(String(localized: "custom_pack.delete_confirm_action"), role: .destructive) {
                deleteCustomPack(category)
            }
            Button(String(localized: "custom_pack.cancel"), role: .cancel) {
                pendingDeleteCategory = nil
            }
        } message: { _ in
            Text("custom_pack.delete_confirm_message")
        }
    }

    // MARK: - Custom packs section

    @ViewBuilder
    private var customPacksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("categories.custom_packs_section_title")
                .font(.evolventa(size: 15, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.top, 6)

            ForEach(customPackStore.packs, id: \.id) { category in
                let isLocked = !subscriptionManager.isPremium
                CategoryCard(
                    category: category,
                    isSelected: selectedCategoryID == category.id,
                    isLocked: isLocked,
                    onTap: {
                        if isLocked {
                            HapticsManager.notification(.warning)
                            AnalyticsService.logCategoryLockedTapped(categoryName: category.name)
                            router.navigate(to: .categoryPaywall)
                            return
                        }
                        HapticsManager.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategoryID = category.id
                        }
                        gameSession.selectedCategory = category
                        AnalyticsService.logCustomPackSelected(categoryName: category.name)
                    },
                    onDelete: {
                        HapticsManager.impact(.light)
                        pendingDeleteCategory = category
                    }
                )
            }

            createPackCTA
        }
    }

    private var createPackCTA: some View {
        let isPremiumLocked = !subscriptionManager.isPremium
        let canCreateMore = customPackStore.canCreateMore

        return Button(action: {
            HapticsManager.impact(.light)
            if isPremiumLocked {
                AnalyticsService.logCategoryLockedTapped(categoryName: "custom_ai_pack_cta")
                router.navigate(to: .categoryPaywall)
                return
            }
            if canCreateMore {
                router.navigate(to: .customWordPackCreator)
            } else {
                HapticsManager.notification(.warning)
                AnalyticsService.logCustomPackLimitReached()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: (isPremiumLocked || !canCreateMore) ? "lock.fill" : "wand.and.stars")
                        .font(.evolventa(size: 20, weight: .bold))
                        .foregroundColor(.appAccentHigh)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("categories.custom_pack_create_cta")
                        .font(.evolventa(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(createPackSubtitle(isPremiumLocked: isPremiumLocked, canCreateMore: canCreateMore))
                        .font(.evolventa(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.evolventa(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.appSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.3, dash: [6, 5]))
                    .foregroundColor(Color.appAccent.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
        .opacity((isPremiumLocked || canCreateMore) ? 1.0 : 0.6)
    }

    private func createPackSubtitle(isPremiumLocked: Bool, canCreateMore: Bool) -> String {
        if isPremiumLocked {
            return String(localized: "categories.custom_pack_unlock_premium")
        }
        if canCreateMore {
            return String(format: String(localized: "custom_pack.remaining_slots_format"), customPackStore.remainingSlots, CustomWordPackStore.maxPackCount)
        }
        return String(localized: "categories.custom_pack_limit_reached")
    }

    private func deleteCustomPack(_ category: Category) {
        customPackStore.delete(category)
        AnalyticsService.logCustomPackDeleted(categoryName: category.name, remainingPackCount: customPackStore.packs.count)
        pendingDeleteCategory = nil
        if selectedCategoryID == category.id {
            selectedCategoryID = nil
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
        let combined = allSelectableCategories
        guard !combined.isEmpty else {
            selectedCategoryID = nil
            gameSession.selectedCategory = nil
            return
        }

        if let selectedCategoryID,
           let selectedCategory = combined.first(where: { $0.id == selectedCategoryID }) {
            gameSession.selectedCategory = selectedCategory
            return
        }

        if let previousCategory = gameSession.selectedCategory,
           let restoredCategory = combined.first(where: { $0.id == previousCategory.id || $0.name == previousCategory.name }) {
            selectedCategoryID = restoredCategory.id
            gameSession.selectedCategory = restoredCategory
            return
        }

        if let firstCategory = combined.first(where: { !($0.isPremium && !subscriptionManager.isPremium) }) {
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
    var onDelete: (() -> Void)? = nil

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
                        } else if category.isCustom {
                            aiChip
                        }
                    }

                    Text(verbatim: category.description)
                        .font(.evolventa(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
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
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.evolventa(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
    }

    /// "AI" pill shown on generated custom packs when not selected/locked (mirrors `proChip` styling).
    private var aiChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.evolventa(size: 10, weight: .bold))
            Text(verbatim: "AI")
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

/// Promo banner inserted as the 4th list item, encouraging non-premium users toward the paywall.
struct PremiumPromoBannerCard: View {
    let action: () -> Void
    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: "crown.fill")
                        .font(.evolventa(size: 21, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("categories.premium_banner_title")
                        .font(.evolventa(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text("categories.premium_banner_subtitle")
                        .font(.evolventa(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.evolventa(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccentHigh],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(isPulsing ? 0.45 : 0.25), lineWidth: 1)
            )
            .shadow(color: Color.appAccent.opacity(isPulsing ? 0.65 : 0.35), radius: isPulsing ? 20 : 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPulsing ? 1.015 : 1.0)
        .animation(
            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
            value: isPulsing
        )
        .onAppear {
            isPulsing = true
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
            AnalyticsService.logCategoryInfoStepViewed(stepIndex: currentStep)
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
