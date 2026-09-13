import FirebaseFirestore
import Foundation

/// Drives the one-time post-game pulse survey: eligibility after the 2nd completed game,
/// retroactive backfill for users who already had games before this feature shipped,
/// and persistence of the response to Firestore.
enum SurveyService {
    enum Choice: String {
        case everyone
        case some
        case fellFlat = "fell_flat"
    }

    private static let gamesPlayedCountKey = "surveyGamesPlayedCount"
    private static let hasShownSurveyKey = "hasShownPostGameSurvey"
    private static let hasRunMigrationKey = "hasRunSurveyMigration"

    /// Call once per completed round (e.g. from ResultView.onAppear's post-game block).
    /// Returns true exactly once, when the user reaches their 2nd counted game and hasn't
    /// already seen the survey.
    static func recordCompletedGameAndCheckEligibility() -> Bool {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hasShownSurveyKey) else { return false }

        let newCount = defaults.integer(forKey: gamesPlayedCountKey) + 1
        defaults.set(newCount, forKey: gamesPlayedCountKey)
        return newCount >= 2
    }

    /// Seeds the counter for users who already had game history before this feature shipped,
    /// so their very next completed game (not a fresh 2nd one) triggers the survey.
    /// Mirrors RateUsService.migrateLegacyFlagIfNeeded's one-time backfill idiom.
    static func migrateExistingUsersIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hasRunMigrationKey) else { return }
        defaults.set(true, forKey: hasRunMigrationKey)

        guard !defaults.bool(forKey: hasShownSurveyKey) else { return }
        guard defaults.integer(forKey: gamesPlayedCountKey) == 0 else { return }
        guard AnalyticsService.totalGamesPlayed >= 1 else { return }

        defaults.set(1, forKey: gamesPlayedCountKey)
    }

    /// Marks the survey as seen so it never shows again, regardless of how the user
    /// interacted with it (answered, skipped, or swiped away).
    static func markShown() {
        UserDefaults.standard.set(true, forKey: hasShownSurveyKey)
        AdGateService.suppressAds(for: 300)
        AnalyticsService.logEvent("post_game_survey_shown")
    }

    /// Writes the choice made on step 1. Called immediately on tap so the core signal
    /// survives even if the user closes the sheet before reaching step 2.
    static func submitChoice(_ choice: Choice, documentID: String) {
        AnalyticsService.logEvent("post_game_survey_answered", parameters: [
            "choice": choice.rawValue
        ])

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        Firestore.firestore().collection("survey_responses").document(documentID).setData([
            "choice": choice.rawValue,
            "appVersion": appVersion,
            "gamesPlayedAtResponse": UserDefaults.standard.integer(forKey: gamesPlayedCountKey),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            logWriteResult(error, context: "choice")
        }
    }

    /// Adds the open-text and/or email fields from step 2 onto the existing response document.
    static func submitDetails(openText: String, email: String, documentID: String) {
        var fields: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        let trimmedText = openText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty { fields["openText"] = trimmedText }
        if !trimmedEmail.isEmpty { fields["email"] = trimmedEmail }

        guard fields.count > 1 else { return }
        Firestore.firestore().collection("survey_responses").document(documentID).setData(fields, merge: true) { error in
            logWriteResult(error, context: "details")
        }
    }

    /// Surfaces write failures (e.g. missing Firestore database, denied rules) in the console
    /// and analytics, since a silently dropped `setData` call otherwise leaves no trace.
    private static func logWriteResult(_ error: Error?, context: String) {
        guard let error else { return }
        print("SurveyService: Firestore write failed (\(context)): \(error)")
        AnalyticsService.logEvent("post_game_survey_write_failed", parameters: [
            "context": context,
            "error": error.localizedDescription
        ])
    }

    #if DEBUG
    static func resetSurveyForQA() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: gamesPlayedCountKey)
        defaults.removeObject(forKey: hasShownSurveyKey)
        defaults.removeObject(forKey: hasRunMigrationKey)
    }

    static func simulateEligibleForQA() {
        let defaults = UserDefaults.standard
        defaults.set(1, forKey: gamesPlayedCountKey)
        defaults.set(false, forKey: hasShownSurveyKey)
    }
    #endif
}
