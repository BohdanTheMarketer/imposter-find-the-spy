import Adapty
import AdaptyUI
import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import FirebaseInstallations
import SwiftUI

@main
struct ImposterGameApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var adaptyService = AdaptyService.shared

    init() {
        AppFontRegistrar.registerAppFonts()
        FirebaseApp.configure()
        // One id across GA4, Crashlytics, Amplitude, Adapty/Apple and the BigQuery warehouse.
        Analytics.setUserID(UserIdentity.id)
        Crashlytics.crashlytics().setUserID(UserIdentity.id)
        WarehouseUploader.start()
        AnalyticsService.setInstallWeekIfNeeded()
        AnalyticsService.setAppLanguage(LocalizationService.shared.currentLocaleCode)
        SeasonalEvent.reportEligibility()
        AdMobService.shared.start()

        let config = AdaptyConfiguration
            .builder(withAPIKey: AppConstants.adaptyPublicKey)
            .with(logLevel: .info)
            .build()
        Adapty.delegate = AdaptyService.shared
        Task {
            try await Adapty.activate(with: config)
            try await AdaptyUI.activate()
            // customerUserId stays the Firebase Installation ID so existing Adapty profiles are
            // untouched; the appAccountToken is what Apple echoes back in server notifications,
            // which is how the warehouse ties every payment to `UserIdentity`.
            if let installationId = try? await Installations.installations().installationID() {
                try? await Adapty.identify(installationId, withAppAccountToken: UserIdentity.uuid)
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
                            .seasonalDecoration()
                    case .categories:
                        CategoriesView()
                            .seasonalDecoration()
                    case .gameSettings:
                        GameSettingsView()
                            .seasonalDecoration()
                    case .roleReveal:
                        RoleRevealView()
                    case .gameTimer:
                        GameTimerView()
                            .seasonalDecoration()
                    case .voting:
                        VotingView()
                            .seasonalDecoration()
                    case .result:
                        ResultView()
                            .seasonalDecoration()
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
