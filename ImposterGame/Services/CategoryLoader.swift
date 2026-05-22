import Foundation

enum CategoryLoader {

    // MARK: - Locale resolution

    /// Returns an ordered list of folder names to try when loading a word pack.
    /// Priority: exact BCP-47 (e.g. "es-MX") → language-only (e.g. "es") → "en".
    /// Reads `AppleLanguages` (set by `LocalizationService`) before falling back to `Locale.current`,
    /// so user overrides apply before the next cold start picks them up automatically.
    static func resolvedLocaleFolders() -> [String] {
        let identifier = preferredLocaleIdentifier()
        let locale = Locale(identifier: identifier)
        let lang = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? ""
        let bcp47 = region.isEmpty ? lang : "\(lang)-\(region)"

        // Map non-standard or variant codes onto the folder names we ship.
        let overrides: [String: String] = [
            "es-419": "es-MX",
            "es": "es-MX",
            "pt": "pt-BR"
        ]

        let primary = overrides[bcp47] ?? bcp47
        let language = overrides[lang] ?? lang

        var folders: [String] = []
        folders.append(primary)
        if language != primary {
            folders.append(language)
        }
        if !folders.contains("en") {
            folders.append("en")
        }
        return folders
    }

    private static func preferredLocaleIdentifier() -> String {
        if let override = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = override.first {
            return first
        }
        return Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
    }

    // MARK: - Loading

    static let fileNames: [String] = [
        "party_time",
        "food",
        "celebrities",
        "hobbies",
        "family",
        "school",
        "spicy",
        "sports",
        "travel",
        "work_life",
        "movies",
        "shopping",
        "tech",
        "superpowers",
        "music",
        "places"
    ]

    static func loadCategories() -> [Category] {
        let localeFolders = resolvedLocaleFolders()
        var categories: [Category] = []

        for fileName in fileNames {
            if let category = loadCategory(fileName: fileName, localeFolders: localeFolders) {
                categories.append(category)
            }
        }

        if categories.isEmpty {
            categories = defaultCategories()
        }

        return categories
    }

    private static func loadCategory(fileName: String, localeFolders: [String]) -> Category? {
        for folder in localeFolders {
            let subdirectory = "WordPacks/\(folder)"
            guard let url = Bundle.main.url(
                forResource: fileName,
                withExtension: "json",
                subdirectory: subdirectory
            ) else { continue }

            do {
                let data = try Data(contentsOf: url)
                let wordPack = try JSONDecoder().decode(WordPack.self, from: data)
                return Category(
                    name: wordPack.category,
                    icon: wordPack.icon,
                    description: wordPack.description,
                    words: wordPack.words,
                    imposterHints: wordPack.imposterHints ?? [],
                    isPremium: wordPack.isPremium
                )
            } catch {
                print("[CategoryLoader] Failed to decode \(subdirectory)/\(fileName).json: \(error)")
                AnalyticsService.logEvent("category_load_failed", parameters: [
                    "file": fileName,
                    "locale_folder": folder
                ])
            }
        }

        print("[CategoryLoader] Failed to locate \(fileName).json in any locale folder: \(localeFolders)")
        AnalyticsService.logEvent("category_load_failed", parameters: [
            "file": fileName,
            "locale_folders_tried": localeFolders.joined(separator: ",")
        ])
        return nil
    }

    // MARK: - Fallback

    private static func defaultCategories() -> [Category] {
        return [
            Category(name: "Party Time", icon: "party.popper", description: "Easygoing fun with laughs and a bit of chaos — perfect for any group vibe!", words: ["DJ", "Karaoke", "Beer Pong", "Dance Floor", "Cocktail", "Disco Ball", "Confetti", "Shot Glass", "Limbo", "Bouncer", "Playlist", "Strobe Light", "Red Cup", "Toast", "Champagne", "Photo Booth", "Balloon", "Costume", "Hangover", "Designated Driver", "Ice Breaker", "Dare", "Spin the Bottle", "Body Shot", "Conga Line", "Foam Party", "VIP Section", "Cover Charge", "Last Call", "Jukebox", "Keg Stand", "Flip Cup", "Glow Stick", "Crowd Surf", "Encore", "Pregame", "Afterparty", "House Party", "Pool Party", "Roof Party", "Toga Party", "Theme Party", "Open Bar", "Punch Bowl", "Bartender", "Smoke Machine", "Laser Show", "Mosh Pit", "Stage Dive", "Rave"], isPremium: false),
            Category(name: "Food", icon: "fork.knife", description: "Tasty topics, but say the wrong thing and you're toast!", words: ["Sushi", "Barbecue", "Vegan", "Pizza", "Taco", "Croissant", "Pancake", "Waffle", "Burrito", "Ramen", "Dim Sum", "Fondue", "Soufflé", "Paella", "Ceviche", "Cheeseburger", "Hot Dog", "French Fries", "Onion Rings", "Milkshake", "Ice Cream Sundae", "Brownie", "Cheesecake", "Tiramisu", "Crème Brûlée", "Lobster", "Caviar", "Truffle", "Oyster", "Filet Mignon", "Avocado Toast", "Acai Bowl", "Smoothie", "Kale Salad", "Kombucha", "Food Truck", "Buffet", "Doggy Bag", "Tip Jar", "Drive-Through", "Chopsticks", "Fortune Cookie", "Sriracha", "Wasabi", "Maple Syrup", "Peanut Butter", "Nutella", "Sourdough", "Bacon", "Fried Chicken"], isPremium: false)
        ]
    }
}
