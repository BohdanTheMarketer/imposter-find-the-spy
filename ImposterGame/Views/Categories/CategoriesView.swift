import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var gameSession: GameSession
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var categories: [Category] = []
    @State private var selectedCategoryID: UUID?

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
                        Image(systemName: "house.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Categories")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear.frame(width: 18, height: 18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Category list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(categories) { category in
                            CategoryCard(
                                category: category,
                                isSelected: selectedCategoryID == category.id,
                                isLocked: category.isPremium && !subscriptionManager.isPremium,
                                onTap: {
                                    if category.isPremium && !subscriptionManager.isPremium {
                                        HapticsManager.notification(.warning)
                                        return
                                    }
                                    HapticsManager.selection()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategoryID = category.id
                                    }
                                    gameSession.selectedCategory = category
                                    router.navigate(to: .gameSettings)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            categories = CategoryLoader.loadCategories()
            selectedCategoryID = nil
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

                // Category icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                    Image(systemName: category.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
