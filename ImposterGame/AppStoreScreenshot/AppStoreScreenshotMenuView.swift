#if DEBUG
import SwiftUI

/// Debug root: pick a screen, session is auto-seeded. Swipe from the left edge to return to this menu.
struct AppStoreScreenshotMenuView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var gameSession: GameSession

    var body: some View {
        List {
            Section {
                Text("Launch argument: -AppStoreScreenshots")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Jump + seed") {
                jumpRow(title: "01 Onboarding", screen: .onboarding)
                jumpRow(title: "02 Player setup", screen: .playerSetup)
                jumpRow(title: "03 Categories", screen: .categories)
                jumpRow(title: "04 Game settings", screen: .gameSettings)
                jumpRow(title: "05 Role reveal (crew first)", screen: .roleReveal)
                Button {
                    jump {
                        AppStoreScreenshotSeeder.prepareRoleRevealImposterFirst(gameSession: gameSession)
                        router.navigate(to: .roleReveal)
                    }
                } label: {
                    Text("05b Role reveal (imposter first)")
                }
                jumpRow(title: "06 Game timer", screen: .gameTimer)
                jumpRow(title: "07 Voting", screen: .voting)
                jumpRow(title: "08 Result (players win)", screen: .result)
            }

            Section("Paywall (optional)") {
                jumpRow(title: "Onboarding paywall", screen: .paywall)
                jumpRow(title: "Category paywall", screen: .categoryPaywall)
            }
        }
        .navigationTitle("Screenshot harness")
    }

    private func jumpRow(title: String, screen: AppScreen) -> some View {
        Button(title) {
            jump {
                AppStoreScreenshotSeeder.prepare(for: screen, gameSession: gameSession)
                router.navigate(to: screen)
            }
        }
    }

    private func jump(_ work: @escaping () -> Void) {
        router.popToRoot()
        DispatchQueue.main.async(execute: work)
    }
}

#endif
