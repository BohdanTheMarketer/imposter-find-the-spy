import Adapty
import AdaptyUI
import FirebaseAnalytics
import FirebaseCore
import FirebaseInstallations
import SwiftUI

@main
struct ImposterGameApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var adaptyService = AdaptyService.shared

    init() {
        AppFontRegistrar.registerAppFonts()
        FirebaseApp.configure()
        AnalyticsService.setInstallWeekIfNeeded()
        AnalyticsService.setAppLanguage(LocalizationService.shared.currentLocaleCode)
        SurveyService.migrateExistingUsersIfNeeded()

        let config = AdaptyConfiguration
            .builder(withAPIKey: AppConstants.adaptyPublicKey)
            .with(logLevel: .info)
            .build()
        Adapty.delegate = AdaptyService.shared
        Task {
            try await Adapty.activate(with: config)
            try await AdaptyUI.activate()
            if let installationId = try? await Installations.installations().installationID() {
                try? await Adapty.identify(installationId)
            }

            // Amplitude + Firebase/GA integrations (Adapty Dashboard -> Integrations) need these
            // IDs to attach subscription events to the right user — without them Adapty has
            // nothing to forward events against.
            if let amplitudeDeviceId = AmplitudeManager.shared.getDeviceId() {
                try? await Adapty.setIntegrationIdentifier(.amplitudeDeviceId(amplitudeDeviceId))
            }
            if let firebaseAppInstanceId = Analytics.appInstanceID() {
                try? await Adapty.setIntegrationIdentifier(.firebaseAppInstanceId(firebaseAppInstanceId))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(adaptyService)
                .task { await adaptyService.reloadProfile() }
        }
    }
}

/// Root view observes language changes so the whole UI updates without restart.
private struct AppRootView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var gameSession = GameSession()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @ObservedObject private var localization = LocalizationService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var appUpdateOffer: AppUpdateOffer?

    var body: some View {
        let _ = localization.currentLocaleCode

        NavigationStack(path: $router.path) {
            LoaderView()
                .navigationDestination(for: AppScreen.self) { screen in
                    switch screen {
                    case .onboarding:
                        OnboardingView()
                    case .paywall:
                        OnboardingPaywallView()
                    case .categoryPaywall:
                        CategoryPaywallView()
                    case .playerSetup:
                        PlayerSetupView()
                    case .categories:
                        CategoriesView()
                    case .gameSettings:
                        GameSettingsView()
                    case .roleReveal:
                        RoleRevealView()
                    case .gameTimer:
                        GameTimerView()
                    case .voting:
                        VotingView()
                    case .result:
                        ResultView()
                    case .customWordPackCreator:
                        CustomWordPackGeneratorView()
                    }
                }
        }
        .environmentObject(router)
        .environmentObject(gameSession)
        .environmentObject(subscriptionManager)
        .environmentObject(localization)
        .environment(\.locale, localization.locale)
        .preferredColorScheme(.dark)
        .task {
            scheduleAppUpdateCheck()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task {
                await subscriptionManager.refreshSubscriptionStatus(trigger: "scene_active")
            }
            scheduleAppUpdateCheck()
        }
        .alert(
            String(localized: "app_update.title"),
            isPresented: Binding(
                get: { appUpdateOffer != nil },
                set: { if !$0 { appUpdateOffer = nil } }
            )
        ) {
            Button(String(localized: "app_update.update")) {
                guard let offer = appUpdateOffer else { return }
                AppUpdateService.logUpdateTapped(
                    localVersion: currentAppVersion,
                    storeVersion: offer.storeVersion
                )
                AppUpdateService.openAppStore(url: offer.storeURL)
                appUpdateOffer = nil
            }
            Button(String(localized: "common.later"), role: .cancel) {
                guard let offer = appUpdateOffer else { return }
                AppUpdateService.recordDismissal(storeVersion: offer.storeVersion)
                AppUpdateService.logDismissed(
                    localVersion: currentAppVersion,
                    storeVersion: offer.storeVersion
                )
                appUpdateOffer = nil
            }
        } message: {
            Text("app_update.message")
        }
    }

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private func scheduleAppUpdateCheck() {
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let offer = await AppUpdateService.checkForUpdateIfNeeded() else { return }
            appUpdateOffer = offer
            AppUpdateService.logPromptShown(
                localVersion: currentAppVersion,
                storeVersion: offer.storeVersion
            )
        }
    }
}
