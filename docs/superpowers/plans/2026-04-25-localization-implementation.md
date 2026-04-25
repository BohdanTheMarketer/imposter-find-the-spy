# Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a fully localized iOS app across 25 locales — UI strings via `Localizable.strings`, 8 culturally-adapted word packs via locale-folder JSON, and automatic locale resolution at runtime with no in-app picker.

**Architecture:** `Localizable.strings` in `.lproj` folders for UI (SwiftUI resolves automatically); `Resources/WordPacks/{locale}/filename.json` for word packs; `CategoryLoader` resolves the right folder from `Locale.current` with a 3-tier fallback (exact BCP-47 → language-only → en). 8 packs (celebrities, hobbies, school, shopping, tech, superpowers, travel, work_life) live in `en/` only and fall back gracefully.

**Tech Stack:** Swift 5.9, SwiftUI, iOS 16+, XcodeGen (`project.yml`), `NSLocalizedString` / `LocalizedStringKey`, `.stringsdict` for plural forms.

---

## Locale Reference Table

| Folder name | iOS locale identifier | Notes |
|---|---|---|
| `en` | `en`, `en-US` | Base / development locale |
| `en-GB` | `en-GB` | British English |
| `es-MX` | `es-MX`, `es-419` (LATAM fallback) | Mexican / LATAM Spanish |
| `es-ES` | `es-ES` | Spain Spanish |
| `pt-BR` | `pt-BR` | Brazilian Portuguese |
| `de` | `de`, `de-DE` | German |
| `fr` | `fr`, `fr-FR` | French |
| `it` | `it`, `it-IT` | Italian |
| `tr` | `tr`, `tr-TR` | Turkish |
| `ar` | `ar`, `ar-SA`, `ar-AE` | Arabic — RTL |
| `uk` | `uk`, `uk-UA` | Ukrainian |
| `pl` | `pl`, `pl-PL` | Polish |
| `cs` | `cs`, `cs-CZ` | Czech |
| `hu` | `hu`, `hu-HU` | Hungarian |
| `ro` | `ro`, `ro-RO` | Romanian |
| `el` | `el`, `el-GR` | Greek |
| `id` | `id`, `id-ID` | Indonesian |
| `vi` | `vi`, `vi-VN` | Vietnamese |
| `th` | `th`, `th-TH` | Thai |
| `ja` | `ja`, `ja-JP` | Japanese |
| `ko` | `ko`, `ko-KR` | Korean |
| `zh-Hans` | `zh-Hans`, `zh-CN`, `zh-SG` | Simplified Chinese |
| `nl` | `nl`, `nl-NL` | Dutch |
| `sv` | `sv`, `sv-SE` | Swedish |
| `no` | `no`, `nb`, `nb-NO` | Norwegian Bokmål |

---

## File Map

### Created / moved
```
ImposterGame/
  Resources/
    WordPacks/
      en/                        ← 16 JSON files MOVED here from WordPacks/
      en-GB/                     ← 8 new localized JSON files
      es-MX/  es-ES/  pt-BR/  de/  fr/  it/  tr/  ar/  uk/
      pl/  cs/  hu/  ro/  el/  id/  vi/  th/  ja/  ko/
      zh-Hans/  nl/  sv/  no/   ← 8 new localized JSON files each

  en.lproj/
    Localizable.strings          ← new base English UI keys
    Localizable.stringsdict      ← new plural rules (English)
  en-GB.lproj/
    Localizable.strings          ← new
  es-MX.lproj/
    Localizable.strings
    Localizable.stringsdict
  … (one .lproj per locale × 25 total)
```

### Modified
```
ImposterGame/Services/CategoryLoader.swift
ImposterGame/Views/GameSettings/GameSettingsView.swift
ImposterGame/Views/PlayerSetup/PlayerSetupView.swift
ImposterGame/Views/RoleReveal/RoleRevealView.swift
ImposterGame/Views/Voting/VotingView.swift
ImposterGame/Views/Result/ResultView.swift
ImposterGame/Views/Onboarding/OnboardingView.swift
ImposterGame/Views/GameTimer/GameTimerView.swift
ImposterGame/Views/Paywall/PaywallView.swift
ImposterGame/Views/Paywall/CategoryPaywallView.swift
ImposterGame/Views/Categories/CategoriesView.swift
ImposterGame/Views/Loader/LoaderView.swift
project.yml
```

---

## Phase 1 — Infrastructure

### Task 1: Move word packs into `en/` subfolder

**Files:**
- Move: `ImposterGame/Resources/WordPacks/*.json` → `ImposterGame/Resources/WordPacks/en/*.json`

- [ ] **Step 1: Create the en/ directory and move all 16 JSON files**

```bash
cd "/Users/bohdanmacbook/Imposter Find The Spy"
mkdir -p ImposterGame/Resources/WordPacks/en
mv ImposterGame/Resources/WordPacks/party_time.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/food.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/celebrities.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/hobbies.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/family.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/school.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/spicy.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/sports.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/travel.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/work_life.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/movies.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/shopping.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/tech.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/superpowers.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/music.json ImposterGame/Resources/WordPacks/en/
mv ImposterGame/Resources/WordPacks/places.json ImposterGame/Resources/WordPacks/en/
ls ImposterGame/Resources/WordPacks/en/
```

Expected: 16 JSON files listed.

- [ ] **Step 2: Verify no stray JSON files remain in WordPacks root**

```bash
ls ImposterGame/Resources/WordPacks/
```

Expected: only the `en/` directory (plus any locale subdirectories you've already created).

- [ ] **Step 3: Commit**

```bash
git add -A ImposterGame/Resources/WordPacks/
git commit -m "refactor: move word pack JSONs into WordPacks/en/ subfolder"
```

---

### Task 2: Update `CategoryLoader.swift` with locale-aware loading

**Files:**
- Modify: `ImposterGame/Services/CategoryLoader.swift`

- [ ] **Step 1: Replace the entire file with the updated implementation**

```swift
import Foundation

enum CategoryLoader {

    // MARK: - Locale resolution

    /// Returns an ordered list of folder names to try when loading a word pack.
    /// Priority: exact BCP-47 (e.g. "es-MX") → language-only (e.g. "es") → "en".
    /// Handles non-standard codes iOS may report (es-419, zh-CN, nb-NO, etc.).
    static func resolvedLocaleFolders() -> [String] {
        let locale = Locale.current
        let lang   = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? ""
        let bcp47  = region.isEmpty ? lang : "\(lang)-\(region)"

        // Map non-standard or variant codes to our folder names.
        let overrides: [String: String] = [
            "es-419":  "es-MX",    // LATAM Spanish → Mexican pack
            "zh-CN":   "zh-Hans",  // China mainland → Simplified Chinese
            "zh-SG":   "zh-Hans",  // Singapore → Simplified Chinese
            "nb":      "no",       // Norwegian Bokmål short code
            "nb-NO":   "no",       // Norwegian Bokmål full code
            "no-NO":   "no",
        ]

        let primary  = overrides[bcp47]  ?? bcp47
        let language = overrides[lang]   ?? lang

        if primary == language {
            // E.g. device is "fr" (no region) → try ["fr", "en"]
            return [language, "en"]
        } else {
            // E.g. device is "es-MX" → try ["es-MX", "es", "en"]
            return [primary, language, "en"]
        }
    }

    // MARK: - Loading

    static func loadCategories() -> [Category] {
        let fileNames = [
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

        // All locale folders exhausted — log and return nil.
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
            Category(name: "Food", icon: "fork.knife", description: "Tasty topics, but say the wrong thing and you're toast!", words: ["Sushi", "Barbecue", "Vegan", "Pizza", "Taco", "Croissant", "Pancake", "Waffle", "Burrito", "Ramen", "Dim Sum", "Fondue", "Soufflé", "Paella", "Ceviche", "Cheeseburger", "Hot Dog", "French Fries", "Onion Rings", "Milkshake", "Ice Cream Sundae", "Brownie", "Cheesecake", "Tiramisu", "Crème Brûlée", "Lobster", "Caviar", "Truffle", "Oyster", "Filet Mignon", "Avocado Toast", "Acai Bowl", "Smoothie", "Kale Salad", "Kombucha", "Food Truck", "Buffet", "Doggy Bag", "Tip Jar", "Drive-Through", "Chopsticks", "Fortune Cookie", "Sriracha", "Wasabi", "Maple Syrup", "Peanut Butter", "Nutella", "Sourdough", "Bacon", "Fried Chicken"], isPremium: false),
            Category(name: "Family", icon: "house.fill", description: "Family knows you best — but can they still catch you faking it?", words: ["Grandma", "Dinner Table", "Road Trip", "Family Photo", "Bedtime Story", "Sibling Rivalry", "Chores", "Allowance", "Curfew", "Grounding", "Baby Shower", "Thanksgiving", "Christmas Tree", "Birthday Cake", "Family Reunion", "Minivan", "Diaper", "Lullaby", "Babysitter", "High Chair", "Bunk Bed", "Treehouse", "Homework", "Report Card", "School Bus", "Family Pet", "Goldfish", "Backyard BBQ", "Garage Sale", "Attic", "Basement", "Family Album", "Vacation", "Camping", "Board Game Night", "Pillow Fight", "Hide and Seek", "Tooth Fairy", "Santa Claus", "Easter Egg", "Prom Night", "Graduation", "Wedding", "Anniversary", "Retirement", "Inheritance", "Family Recipe", "Sunday Brunch", "Carpool", "Lemonade Stand"], isPremium: false),
            Category(name: "Places", icon: "map.fill", description: "From airports to zoos — describe the place without giving it away!", words: ["Airport", "Museum", "Hospital", "Beach", "Casino", "Library", "Zoo", "Amusement Park", "Gym", "Restaurant", "Cemetery", "Prison", "Church", "Stadium", "Mall", "Subway Station", "Lighthouse", "Volcano", "Waterfall", "Desert", "Igloo", "Treehouse", "Skyscraper", "Barn", "Haunted House", "Cruise Ship", "Space Station", "Oil Rig", "Vineyard", "Spa", "Laundromat", "Junkyard", "Rooftop", "Underground Bunker", "Penthouse", "Cabin", "Campsite", "Drive-In Theater", "Bowling Alley", "Arcade", "Car Wash", "Gas Station", "Parking Lot", "Elevator", "Balcony", "Backstage", "Courtroom", "Dentist Office", "Barbershop", "Tattoo Parlor"], isPremium: true),
            Category(name: "Sports", icon: "sportscourt.fill", description: "Goals, fouls, and touchdowns — can you fake your way through sports talk?", words: ["Goalkeeper", "Referee", "Dumbbell", "Slam Dunk", "Penalty Kick", "Marathon", "Boxing Ring", "Surfboard", "Skateboard", "Trampoline", "Wrestling", "Archery", "Fencing", "Javelin", "Hurdles", "Relay Race", "High Jump", "Pole Vault", "Shot Put", "Decathlon", "Touchdown", "Home Run", "Hat Trick", "Hole in One", "Knockout", "Free Throw", "Corner Kick", "Yellow Card", "Offside", "Overtime", "Trophy", "Medal", "Podium", "Victory Lap", "Halftime", "Cheerleader", "Mascot", "Locker Room", "Bench Press", "Treadmill", "Yoga Mat", "Protein Shake", "Warm Up", "Cool Down", "Personal Trainer", "MVP", "Draft Pick", "Trade Deadline", "Playoff", "Championship Ring"], isPremium: true),
            Category(name: "Spicy", icon: "flame.fill", description: "Things get heated — risky words for bold players only!", words: ["Handcuffs", "Blind Date", "Skinny Dipping", "Love Letter", "Flirting", "Jealousy", "Heartbreak", "Crush", "Secret Admirer", "Lipstick Mark", "Slow Dance", "Candlelit Dinner", "Rose Petals", "Chocolate Strawberry", "Massage", "Hot Tub", "Dare", "Truth or Dare", "Seven Minutes", "Spin the Bottle", "Wink", "Pickup Line", "Love Triangle", "Rebound", "Ghosting", "Situationship", "Friends with Benefits", "Wingman", "Walk of Shame", "Morning After", "Strip Poker", "Body Language", "Chemistry", "Butterflies", "Soulmate", "Ex", "DM Slide", "Netflix and Chill", "Date Night", "Long Distance", "Love Potion", "Aphrodisiac", "Seduction", "Temptation", "Forbidden Fruit", "Guilty Pleasure", "Fantasy", "Role Play", "Rendezvous", "Affair"], isPremium: true),
            Category(name: "Movies & TV", icon: "film.fill", description: "Lights, camera, action! Describe movie things without spoiling it!", words: ["Popcorn", "Director", "Sequel", "Plot Twist", "Cliffhanger", "Red Carpet", "Oscar", "Stunt Double", "Blooper", "End Credits", "Trailer", "Box Office", "Premiere", "Cameo", "Casting Couch", "Green Screen", "Special Effects", "Sound Track", "Opening Scene", "Flashback", "Narrator", "Villain", "Sidekick", "Love Interest", "Anti-Hero", "Jump Scare", "Car Chase", "Explosion", "Montage", "Time Travel", "Zombie", "Alien Invasion", "Heist", "Courtroom Drama", "Musical Number", "Documentary", "Animation", "Noir", "Western", "Superhero", "Binge Watch", "Season Finale", "Spoiler Alert", "Fan Theory", "Reboot", "Spin-Off", "Crossover", "Post-Credits", "Director's Cut", "Film Festival"], isPremium: true)
        ]
    }
}
```

- [ ] **Step 2: Build the app to confirm CategoryLoader compiles cleanly**

```bash
cd "/Users/bohdanmacbook/Imposter Find The Spy"
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|warning:|Build succeeded|FAILED"
```

Expected: `Build succeeded` — no errors.

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Services/CategoryLoader.swift
git commit -m "feat: update CategoryLoader to use locale-folder word pack lookup with 3-tier BCP-47 fallback"
```

---

### Task 3: Create `.lproj` directories, base `Localizable.strings`, and update `project.yml`

**Files:**
- Create: `ImposterGame/en.lproj/Localizable.strings`
- Create: all other `.lproj` directories (empty `Localizable.strings` placeholders for now — content added in Phase 3)
- Modify: `project.yml`

- [ ] **Step 1: Create all 25 `.lproj` directories inside `ImposterGame/`**

```bash
cd "/Users/bohdanmacbook/Imposter Find The Spy/ImposterGame"
for locale in en en-GB es-MX es-ES pt-BR de fr it tr ar uk pl cs hu ro el id vi th ja ko zh-Hans nl sv no; do
  mkdir -p "${locale}.lproj"
done
ls -d *.lproj
```

Expected: 25 `.lproj` directories listed.

- [ ] **Step 2: Create `en.lproj/Localizable.strings` (base English — complete)**

Create the file `ImposterGame/en.lproj/Localizable.strings` with this exact content:

```
/* Common */
"common.back"                         = "Back";
"common.ok"                           = "OK";
"common.close"                        = "Close";
"common.next"                         = "Next";
"common.continue"                     = "Continue";
"common.coming_soon"                  = "Coming soon";
"common.got_it"                       = "Got It!";

/* Legal */
"legal.privacy_policy"                = "Privacy Policy";
"legal.terms"                         = "Terms & Conditions";
"legal.terms_short"                   = "Terms";
"legal.privacy_short"                 = "Privacy";

/* GameSettings */
"game_settings.title"                         = "Game Settings";
"game_settings.play"                          = "PLAY";
"game_settings.imposter_count_singular"       = "Imposter";
"game_settings.imposter_count_plural"         = "Imposters";
"game_settings.imposters_section_title"       = "Imposters";
"game_settings.imposters_help"                = "How many players should be secret imposters?";
"game_settings.imposters_recommended_format"  = "Recommended for %lld players: %lld";
"game_settings.round_duration_title"          = "Round Duration";
"game_settings.round_duration_help"           = "How long should each discussion round last?";
"game_settings.hints_title"                   = "Hints for Imposters";
"game_settings.hints_help"                    = "Should imposters get a hint about the secret word?";
"game_settings.hints_disabled"                = "Disabled";
"game_settings.hints_enabled"                 = "Enabled";
"game_settings.word_load_error"               = "Couldn\u2019t load a word for this category. Please try again.";

/* PlayerSetup */
"player_setup.title"                          = "Players";
"player_setup.name_placeholder"               = "Enter player name";
"player_setup.continue"                       = "CONTINUE";
"player_setup.player_count_singular"          = "Player";
"player_setup.player_count_plural_suffix"     = "s";
"player_setup.minimum_players_hint"           = "Minimum 3 players to start a game";
"player_setup.options_title"                  = "Options";
"player_setup.options_language"               = "Language";
"player_setup.options_contact"                = "Contact Us";
"player_setup.udid_loading"                   = "Loading\u2026";
"player_setup.udid_unavailable"               = "Unavailable";
"player_setup.udid_label"                     = "UDID:";
"player_setup.udid_toast_loading"             = "UDID is still loading. Try again in a moment.";
"player_setup.udid_toast_unavailable"         = "UDID is unavailable right now.";
"player_setup.udid_toast_copied"              = "UDID copied";
"player_setup.udid_toast_copy_failed"         = "Could not copy UDID";

/* RoleReveal */
"role_reveal.unknown_player"                  = "Unknown";
"role_reveal.imposter_lead_in"                = "You are the";
"role_reveal.imposter_label"                  = "IMPOSTER";
"role_reveal.hint_title"                      = "Imposter hint";
"role_reveal.crew_secret_prefix"              = "Your secret word is:";
"role_reveal.all_done"                        = "Everyone has seen the word";
"role_reveal.pass_phone_format"               = "Pass the phone to %@";
"role_reveal.start_game"                      = "Start Game";
"role_reveal.swipe_instruction"               = "Swipe up to reveal\nthe secret word";

/* Voting */
"voting.title"                                = "Who\u2019s the Imposter?";
"voting.select_singular"                      = "Select %lld player you think are faking it";
"voting.select_plural"                        = "Select %lld players you think are faking it";
"voting.selected_count_format"                = "%lld/%lld selected";
"voting.reveal"                               = "Reveal";

/* Result */
"result.intrigue_the"                         = "THE";
"result.intrigue_moment"                      = "MOMENT";
"result.intrigue_of"                          = "OF";
"result.intrigue_truth"                       = "TRUTH";
"result.title_players_win"                    = "Players Win!";
"result.title_imposter_wins"                  = "Imposter Wins!";
"result.subtitle_single_caught"               = "The imposter was caught";
"result.subtitle_two_caught"                  = "Both imposters caught";
"result.subtitle_all_caught_format"           = "All %lld imposters caught";
"result.subtitle_imposter_escaped"            = "They got away undetected";
"result.badge_players_won"                    = "Players won";
"result.badge_imposter_won"                   = "Imposter won";
"result.screen_title"                         = "Results";
"result.secret_word_label"                    = "SECRET WORD";
"result.play_again"                           = "PLAY AGAIN";
"result.no_imposter"                          = "No imposter found";

/* Onboarding */
"onboarding.page2_title"                      = "Instant Fun\nAnywhere!";
"onboarding.page2_subtitle"                   = "Game night, road trip, or\neven an awkward first meeting \u2014\nFakeit breaks the ice and\nbrings the fun";
"onboarding.page2_cta"                        = "I\u2019m In!";
"onboarding.page3_title"                      = "Who\u2019s Faking It?";
"onboarding.page3_subtitle"                   = "One of you is lying.\nThe rest know the word.\nCan you spot the imposter\nbefore it\u2019s too late?";
"onboarding.page3_cta"                        = "Got It";
"onboarding.hero_talk_smarter"                = "Talk Smarter";
"onboarding.hero_guess_better"                = "Guess Better";
"onboarding.hero_body"                        = "Describe the secret word without saying it.\nBut beware \u2014 the imposter is listening and trying to blend in";
"onboarding.hero_cta"                         = "Let\u2019s Play!";

/* GameTimer */
"game_timer.starts_asking"                    = "Starts Asking!";
"game_timer.section_label"                    = "Timer";
"game_timer.paused"                           = "Paused";
"game_timer.vote_now"                         = "Vote Now";
"game_timer.pause"                            = "Pause";

/* Paywall */
"paywall.headline"                            = "Continue to get\nfull access";
"paywall.plan_yearly"                         = "Yearly";
"paywall.plan_weekly"                         = "Weekly";
"paywall.cancel_anytime"                      = "Cancel anytime";
"paywall.badge_best_value"                    = "Best value";
"paywall.badge_most_popular"                  = "Most popular";
"paywall.trial_prompt_title"                  = "Not sure yet?";
"paywall.trial_prompt_subtitle"               = "Enable free access";
"paywall.trial_legal_line"                    = "0 USD due today \u2022 3 days FREE";
"paywall.continue"                            = "Continue";
"paywall.skip"                                = "Skip";
"paywall.restore"                             = "Restore";
"paywall.restore_alert_title"                 = "Restore Purchases";
"paywall.restore_alert_message"               = "If you have an active subscription, it will be restored shortly.";
"category_paywall.free_access_on"             = "Free access enabled";
"category_paywall.trial_on_subtitle"          = "No commitment, cancel anytime";
"category_paywall.cta_trial"                  = "Try it for Free";

/* Categories */
"categories.title"                            = "Categories";
"categories.play"                             = "Play";
"categories.selection_count_label"            = "Category";
"categories.info.step1_title"                 = "Choose Your Themes";
"categories.info.step1_subtitle"              = "Pick one or more themes to set the mood and match your vibe and party.";
"categories.info.step2_title"                 = "Drop a Clue";
"categories.info.step2_subtitle"              = "Give a clever hint or association. Clear for those in the know - confusing for the imposter.";
"categories.info.step3_title"                 = "Check Your Role";
"categories.info.step3_subtitle"              = "Everyone sees the secret word... except the imposter - they only see their role. Their goal? Blend in.";
"categories.info.step4_title"                 = "Time to Vote";
"categories.info.step4_subtitle"              = "Talk\u2019s over. Now vote to expose the imposter!";
"categories.info.vote_win"                    = "\u2705  Guess right - you win";
"categories.info.vote_lose"                   = "\u274C  Miss - imposter wins";
"categories.info.instant_win_warning"         = "\u26A0\uFE0F If the imposter guesses the word before time runs out, they win instantly";

/* Loader */
"loader.tagline"                              = "FIND  \u2022  ACCUSE  \u2022  SURVIVE";
"loader.imposter_word"                        = "IMPOSTER";
```

- [ ] **Step 3: Create `en.lproj/Localizable.stringsdict` for plural rules (English)**

Create `ImposterGame/en.lproj/Localizable.stringsdict`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>voting.select_count</key>
    <dict>
        <key>NSStringLocalizedFormatKey</key>
        <string>%#@players@</string>
        <key>players</key>
        <dict>
            <key>NSStringFormatSpecTypeKey</key>
            <string>NSStringPluralRuleType</string>
            <key>NSStringFormatValueTypeKey</key>
            <string>lld</string>
            <key>one</key>
            <string>Select %lld player you think are faking it</string>
            <key>other</key>
            <string>Select %lld players you think are faking it</string>
        </dict>
    </dict>
    <key>result.all_caught_format</key>
    <dict>
        <key>NSStringLocalizedFormatKey</key>
        <string>%#@imposters@</string>
        <key>imposters</key>
        <dict>
            <key>NSStringFormatSpecTypeKey</key>
            <string>NSStringPluralRuleType</string>
            <key>NSStringFormatValueTypeKey</key>
            <string>lld</string>
            <key>one</key>
            <string>The imposter was caught</string>
            <key>other</key>
            <string>All %lld imposters caught</string>
        </dict>
    </dict>
</dict>
</plist>
```

- [ ] **Step 4: Create empty `Localizable.strings` in all remaining 24 `.lproj` directories**

```bash
cd "/Users/bohdanmacbook/Imposter Find The Spy/ImposterGame"
for locale in en-GB es-MX es-ES pt-BR de fr it tr ar uk pl cs hu ro el id vi th ja ko zh-Hans nl sv no; do
  touch "${locale}.lproj/Localizable.strings"
done
```

These will be filled in Phase 3.

- [ ] **Step 5: Update `project.yml` — add `knownRegions` so XcodeGen registers all locales**

In `project.yml`, add the following block at the top level (same indentation level as `targets:`):

```yaml
options:
  bundleIdPrefix: com.imposter
  deploymentTarget:
    iOS: "16.0"
  xcodeVersion: "15.0"
  generateEmptyDirectories: true
  developmentLanguage: en
```

Also add to the `settings: base:` block:

```yaml
    LOCALIZATION_PREFERS_STRING_CATALOGS: NO
```

- [ ] **Step 6: Regenerate the Xcode project**

```bash
cd "/Users/bohdanmacbook/Imposter Find The Spy"
xcodegen generate
```

Expected: `✅ Writing project ImposterGame.xcodeproj` with no errors.

- [ ] **Step 7: Build to confirm no regressions**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
```

Expected: `Build succeeded`.

- [ ] **Step 8: Commit**

```bash
git add -A ImposterGame/*.lproj project.yml ImposterGame.xcodeproj/
git commit -m "feat: create 25 .lproj directories and base en.lproj/Localizable.strings with 100 UI keys"
```

---

## Phase 2 — UI String Extraction

> **Pattern:** In SwiftUI, `Text("key")` where the string is a plain literal is automatically treated as a `LocalizedStringKey`. Replace string literals with the Localizable.strings keys. For computed `String` values (not directly inside `Text()`), use `String(localized: "key")`. For `accessibilityLabel`, use `Text(LocalizedStringKey("key"))` or `.accessibilityLabel(Text("key"))`.

---

### Task 4: Update `GameSettingsView.swift`

**Files:**
- Modify: `ImposterGame/Views/GameSettings/GameSettingsView.swift`

- [ ] **Step 1: Replace the `imposterCountLabel` computed property**

Find:
```swift
private var imposterCountLabel: String {
    let word = imposterCount == 1 ? "Imposter" : "Imposters"
    return "\(imposterCount) \(word)"
}
```

Replace with:
```swift
private var imposterCountLabel: String {
    let word = imposterCount == 1
        ? String(localized: "game_settings.imposter_count_singular")
        : String(localized: "game_settings.imposter_count_plural")
    return "\(imposterCount) \(word)"
}
```

- [ ] **Step 2: Replace all `Text(...)` and `.accessibilityLabel(...)` literals in the view body**

Apply these replacements (exact string → localized key):

| Old | New |
|-----|-----|
| `Text("PLAY")` | `Text("game_settings.play")` |
| `.accessibilityLabel("Back")` | `.accessibilityLabel(Text("common.back"))` |
| `Text("Game Settings")` | `Text("game_settings.title")` |
| `Text("Imposters")` (section title) | `Text("game_settings.imposters_section_title")` |
| `Text("How many players should be secret imposters?")` | `Text("game_settings.imposters_help")` |
| `Text("Recommended for \(gameSession.players.count) players: \(maxImposters)")` | `Text(String(format: String(localized: "game_settings.imposters_recommended_format"), gameSession.players.count, maxImposters))` |
| `Text("Round Duration")` | `Text("game_settings.round_duration_title")` |
| `Text("How long should each discussion round last?")` | `Text("game_settings.round_duration_help")` |
| `Text("Hints for Imposters")` | `Text("game_settings.hints_title")` |
| `Text("Should imposters get a hint about the secret word?")` | `Text("game_settings.hints_help")` |
| `Text("Disabled")` | `Text("game_settings.hints_disabled")` |
| `Text("Enabled")` | `Text("game_settings.hints_enabled")` |
| `.alert("Couldn't load a word for this category. Please try again.", ...)` | `.alert(String(localized: "game_settings.word_load_error"), ...)` |
| `Button("OK", role: .cancel)` | `Button(String(localized: "common.ok"), role: .cancel)` |

- [ ] **Step 3: Build and confirm no errors**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
```

- [ ] **Step 4: Commit**

```bash
git add ImposterGame/Views/GameSettings/GameSettingsView.swift
git commit -m "feat: localize GameSettingsView UI strings"
```

---

### Task 5: Update `VotingView.swift`

**Files:**
- Modify: `ImposterGame/Views/Voting/VotingView.swift`

- [ ] **Step 1: Replace the inline plural select string with `.stringsdict` lookup**

Find:
```swift
Text("Select \(maxSelections) player\(maxSelections == 1 ? "" : "s") you think are faking it")
```

Replace with:
```swift
Text(String(format: NSLocalizedString("voting.select_count", comment: ""), maxSelections))
```

*`voting.select_count` is the `.stringsdict` key that handles plural forms automatically.*

- [ ] **Step 2: Replace remaining string literals**

| Old | New |
|-----|-----|
| `Text("Who's the Imposter?")` | `Text("voting.title")` |
| `Text("\(selectedIndices.count)/\(maxSelections) selected")` | `Text(String(format: String(localized: "voting.selected_count_format"), selectedIndices.count, maxSelections))` |
| `Text("Reveal")` | `Text("voting.reveal")` |

- [ ] **Step 3: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/Views/Voting/VotingView.swift
git commit -m "feat: localize VotingView UI strings"
```

---

### Task 6: Update `ResultView.swift`

**Files:**
- Modify: `ImposterGame/Views/Result/ResultView.swift`

- [ ] **Step 1: Replace all string literals in ResultView**

Apply the following key replacements (search for the exact strings in the file):

| Old string | New |
|---|---|
| `"THE"` | `"result.intrigue_the"` |
| `"MOMENT"` | `"result.intrigue_moment"` |
| `"OF"` | `"result.intrigue_of"` |
| `"TRUTH"` | `"result.intrigue_truth"` |
| `"Players Win!"` | `"result.title_players_win"` |
| `"Imposter Wins!"` | `"result.title_imposter_wins"` |
| `"The imposter was caught"` | `"result.subtitle_single_caught"` |
| `"Both imposters caught"` | `"result.subtitle_two_caught"` |
| `"All \(n) imposters caught"` (any format string variant) | `String(format: String(localized: "result.subtitle_all_caught_format"), n)` |
| `"They got away undetected"` | `"result.subtitle_imposter_escaped"` |
| `"Players won"` | `"result.badge_players_won"` |
| `"Imposter won"` | `"result.badge_imposter_won"` |
| `"Results"` | `"result.screen_title"` |
| `"SECRET WORD"` | `"result.secret_word_label"` |
| `"PLAY AGAIN"` | `"result.play_again"` |
| `"No imposter found"` | `"result.no_imposter"` |

*Wrap `String` context (non-Text) replacements with `String(localized: "key")`; `Text(...)` direct replacements with `Text("key")`.*

- [ ] **Step 2: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/Views/Result/ResultView.swift
git commit -m "feat: localize ResultView UI strings"
```

---

### Task 7: Update `RoleRevealView.swift`

**Files:**
- Modify: `ImposterGame/Views/RoleReveal/RoleRevealView.swift`

- [ ] **Step 1: Replace all string literals**

| Old string | New |
|---|---|
| `"Unknown"` | `String(localized: "role_reveal.unknown_player")` |
| `"You are the"` | `"role_reveal.imposter_lead_in"` |
| `"IMPOSTER"` (label) | `"role_reveal.imposter_label"` |
| `"Imposter hint"` | `"role_reveal.hint_title"` |
| `"Your secret word is:"` | `"role_reveal.crew_secret_prefix"` |
| `"Everyone has seen the word"` | `"role_reveal.all_done"` |
| `"Pass the phone to \(name)"` | `String(format: String(localized: "role_reveal.pass_phone_format"), name)` |
| `"Start Game"` | `"role_reveal.start_game"` |
| `"Swipe up to reveal\nthe secret word"` | `"role_reveal.swipe_instruction"` |
| `"Continue"` | `"common.continue"` |

- [ ] **Step 2: Handle the `ImposterMarkGlyph` letter literals**

The animated loader in `RoleRevealView` (or `ImposterRevealBrandMark`) spells out "IMPOSTER" letter-by-letter. Replace the hardcoded `"IMPOSTER"` string (or equivalent array) with:

```swift
let imposterWord = String(localized: "role_reveal.imposter_label")
// Use Array(imposterWord) to get characters for the animation loop
```

- [ ] **Step 3: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/Views/RoleReveal/RoleRevealView.swift
git commit -m "feat: localize RoleRevealView UI strings"
```

---

### Task 8: Update `PlayerSetupView.swift`

**Files:**
- Modify: `ImposterGame/Views/PlayerSetup/PlayerSetupView.swift`

- [ ] **Step 1: Replace all string literals**

| Old string | New |
|---|---|
| `"Enter player name"` (TextField placeholder) | `.placeholder(Text("player_setup.name_placeholder"))` or `String(localized: "player_setup.name_placeholder")` |
| `"CONTINUE"` | `"player_setup.continue"` |
| `"Player"` | `String(localized: "player_setup.player_count_singular")` |
| Player plural suffix `"s"` | Use: `imposterCount == 1 ? "" : String(localized: "player_setup.player_count_plural_suffix")` |
| `"Minimum 3 players to start a game"` | `"player_setup.minimum_players_hint"` |
| `"Players"` (title) | `"player_setup.title"` |
| `"Options"` | `"player_setup.options_title"` |
| `"Language"` | `"player_setup.options_language"` |
| `"Coming soon"` | `"common.coming_soon"` |
| `"Contact Us"` | `"player_setup.options_contact"` |
| `"Privacy Policy"` | `"legal.privacy_policy"` |
| `"Terms & Conditions"` | `"legal.terms"` |
| `"Close"` | `"common.close"` |
| `"Loading…"` | `"player_setup.udid_loading"` |
| `"Unavailable"` | `"player_setup.udid_unavailable"` |
| `"UDID:"` | `"player_setup.udid_label"` |
| Toast strings | `String(localized: "player_setup.udid_toast_loading")` etc. |

- [ ] **Step 2: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/Views/PlayerSetup/PlayerSetupView.swift
git commit -m "feat: localize PlayerSetupView UI strings"
```

---

### Task 9: Update `OnboardingView.swift`

**Files:**
- Modify: `ImposterGame/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Replace all string literals**

| Old string | New |
|---|---|
| `"Instant Fun\nAnywhere!"` | `"onboarding.page2_title"` |
| `"Game night, road trip..."` | `"onboarding.page2_subtitle"` |
| `"I'm In!"` | `"onboarding.page2_cta"` |
| `"Who's Faking It?"` | `"onboarding.page3_title"` |
| `"One of you is lying..."` | `"onboarding.page3_subtitle"` |
| `"Got It"` | `"onboarding.page3_cta"` |
| `"Talk Smarter"` | `"onboarding.hero_talk_smarter"` |
| `"Guess Better"` | `"onboarding.hero_guess_better"` |
| `"Describe the secret word..."` | `"onboarding.hero_body"` |
| `"Let's Play!"` | `"onboarding.hero_cta"` |

- [ ] **Step 2: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/Views/Onboarding/OnboardingView.swift
git commit -m "feat: localize OnboardingView UI strings"
```

---

### Task 10: Update `GameTimerView.swift`, `PaywallView.swift`, `CategoryPaywallView.swift`

**Files:**
- Modify: `ImposterGame/Views/GameTimer/GameTimerView.swift`
- Modify: `ImposterGame/Views/Paywall/PaywallView.swift`
- Modify: `ImposterGame/Views/Paywall/CategoryPaywallView.swift`

- [ ] **Step 1: GameTimerView — replace all string literals**

| Old | New |
|---|---|
| `"Starts Asking!"` | `"game_timer.starts_asking"` |
| `"Timer"` | `"game_timer.section_label"` |
| `"Paused"` | `"game_timer.paused"` |
| `"Continue"` | `"common.continue"` |
| `"Vote Now"` | `"game_timer.vote_now"` |
| `"Pause"` | `"game_timer.pause"` |

- [ ] **Step 2: PaywallView — replace all string literals**

| Old | New |
|---|---|
| `"Continue to get\nfull access"` | `"paywall.headline"` |
| `"Yearly"` | `"paywall.plan_yearly"` |
| `"Weekly"` | `"paywall.plan_weekly"` |
| `"Cancel anytime"` | `"paywall.cancel_anytime"` |
| `"Best value"` | `"paywall.badge_best_value"` |
| `"Most popular"` | `"paywall.badge_most_popular"` |
| `"Not sure yet?"` | `"paywall.trial_prompt_title"` |
| `"Enable free access"` | `"paywall.trial_prompt_subtitle"` |
| `"0 USD due today • 3 days FREE"` | `"paywall.trial_legal_line"` |
| `"Continue"` | `"paywall.continue"` |
| `"Skip"` | `"paywall.skip"` |
| `"Restore"` | `"paywall.restore"` |
| `"Restore Purchases"` | `"paywall.restore_alert_title"` |
| `"OK"` | `"common.ok"` |
| `"If you have an active subscription..."` | `"paywall.restore_alert_message"` |
| `"Terms"` | `"legal.terms_short"` |
| `"Privacy"` | `"legal.privacy_short"` |

- [ ] **Step 3: CategoryPaywallView — replace literals (shared keys from paywall + these unique ones)**

| Old | New |
|---|---|
| `"Free access enabled"` | `"category_paywall.free_access_on"` |
| `"No commitment, cancel anytime"` | `"category_paywall.trial_on_subtitle"` |
| `"Try it for Free"` | `"category_paywall.cta_trial"` |

All other strings in `CategoryPaywallView` share keys with `PaywallView` (same `paywall.*` keys).

- [ ] **Step 4: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/Views/GameTimer/ ImposterGame/Views/Paywall/
git commit -m "feat: localize GameTimerView and paywall UI strings"
```

---

### Task 11: Update `CategoriesView.swift` and `LoaderView.swift`

**Files:**
- Modify: `ImposterGame/Views/Categories/CategoriesView.swift`
- Modify: `ImposterGame/Views/Loader/LoaderView.swift`

- [ ] **Step 1: CategoriesView — replace all string literals**

| Old | New |
|---|---|
| `"Categories"` | `"categories.title"` |
| `"Play"` | `"categories.play"` |
| `"Category"` | `"categories.selection_count_label"` |
| `"Choose Your Themes"` | `"categories.info.step1_title"` |
| `"Pick one or more themes..."` | `"categories.info.step1_subtitle"` |
| `"Next"` | `"common.next"` |
| `"Drop a Clue"` | `"categories.info.step2_title"` |
| `"Give a clever hint..."` | `"categories.info.step2_subtitle"` |
| `"Check Your Role"` | `"categories.info.step3_title"` |
| `"Everyone sees the secret word..."` | `"categories.info.step3_subtitle"` |
| `"Time to Vote"` | `"categories.info.step4_title"` |
| `"Talk's over. Now vote..."` | `"categories.info.step4_subtitle"` |
| `"Got It!"` | `"common.got_it"` |
| `"✅  Guess right - you win"` | `"categories.info.vote_win"` |
| `"❌  Miss - imposter wins"` | `"categories.info.vote_lose"` |
| `"⚠️ If the imposter guesses..."` | `"categories.info.instant_win_warning"` |

*Note: The emoji strings (`"🏟️ 🌶️ 🪩"`, `"🍌"`, `"👤 👤 🕵️ 👤"`) are decorative. Leave them as string literals — they are not user-readable copy.*

- [ ] **Step 2: LoaderView — replace the animated word**

Find the code that uses individual letter literals `"I"`, `"M"`, `"P"`, `"O"`, `"S"`, `"T"`, `"E"`, `"R"` or any array/string spelling "IMPOSTER". Replace with:

```swift
// At the start of LoaderView (or where the animated word is defined):
private var imposterLetters: [String] {
    Array(String(localized: "loader.imposter_word")).map { String($0) }
}
```

Then use `imposterLetters` wherever the individual letter strings were used.

Also replace `"FIND  •  ACCUSE  •  SURVIVE"` → `Text("loader.tagline")`.

Also replace `"WHO'S"` and `"THE"` if they appear as Text literals:

| Old | New |
|---|---|
| `"WHO'S"` | Keep as-is unless it appears in the animated brand mark — then note it's decorative and skip localization. |
| `"THE"` | Same — skip if purely decorative branding. |
| `"FIND  •  ACCUSE  •  SURVIVE"` | `"loader.tagline"` |

- [ ] **Step 3: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/Views/Categories/CategoriesView.swift ImposterGame/Views/Loader/LoaderView.swift
git commit -m "feat: localize CategoriesView and LoaderView UI strings"
```

---

## Phase 3 — UI String Translations

> **Generation guidelines for every locale below:**
> - Keep all key names identical to `en.lproj/Localizable.strings`
> - Keep `%lld`, `%@`, `\n`, `\u2019` (apostrophe), `\u2014` (em-dash), `\u2022` (bullet) escape sequences in the same positions
> - Paywall price string `"paywall.trial_legal_line"` — the "0 USD" part can stay in USD or be adapted to the locale's currency symbol if a dynamic price is not yet implemented; for now keep `"0 USD"` (price strings will be dynamic later)
> - `loader.imposter_word` — translate the word "IMPOSTER" into the target language (the word will be split character-by-character for the animated loader)
> - `loader.tagline` — translate "FIND • ACCUSE • SURVIVE" meaningfully; keep bullet separators
> - For Arabic (`ar`), write strings in Arabic script right-to-left; format specifiers (`%lld`, `%@`) stay left-to-right in the file
> - `.stringsdict` plural rules must match the target language's plural categories (details below)

### Plural category reference

| Locale | Plural categories | Notes |
|---|---|---|
| en, de, nl, sv, no, id, vi, th, tr | one / other | Simple |
| fr, pt-BR | one / other | French: 0 and 1 are "one" |
| es-MX, es-ES, it | one / other | |
| ar | zero / one / two / few / many / other | 6 forms |
| pl | one / few / many / other | |
| cs, sk | one / few / many / other | |
| hu, ro | one / few / many / other | |
| uk | one / few / many / other | |
| el | one / other | |
| ja, ko, zh-Hans | other (no plural) | |
| en-GB | one / other | Same as en |

---

### Task 12: Romance language UI translations (es-MX, es-ES, pt-BR, fr, it)

**Files:**
- Create/fill: `ImposterGame/es-MX.lproj/Localizable.strings`
- Create/fill: `ImposterGame/es-MX.lproj/Localizable.stringsdict`
- Create/fill: `ImposterGame/es-ES.lproj/Localizable.strings`
- Create/fill: `ImposterGame/es-ES.lproj/Localizable.stringsdict`
- Create/fill: `ImposterGame/pt-BR.lproj/Localizable.strings`
- Create/fill: `ImposterGame/pt-BR.lproj/Localizable.stringsdict`
- Create/fill: `ImposterGame/fr.lproj/Localizable.strings`
- Create/fill: `ImposterGame/fr.lproj/Localizable.stringsdict`
- Create/fill: `ImposterGame/it.lproj/Localizable.strings`
- Create/fill: `ImposterGame/it.lproj/Localizable.stringsdict`

- [ ] **Step 1: Generate and write `es-MX.lproj/Localizable.strings`**

Translate every key from `en.lproj/Localizable.strings` into Mexican Spanish. Key cultural notes:
- Use `tú` (informal) throughout
- `"game_settings.play"` = `"JUGAR"`
- `"role_reveal.imposter_label"` = `"IMPOSTOR"` (Spanish spelling)
- `"loader.imposter_word"` = `"IMPOSTOR"`
- `"loader.tagline"` = `"ENCUENTRA  •  ACUSA  •  SOBREVIVE"`
- `"voting.title"` = `"¿Quién es el Impostor?"`
- `"onboarding.hero_cta"` = `"¡Vamos a Jugar!"`

Write the complete translated `.strings` file (all ~100 keys) to `ImposterGame/es-MX.lproj/Localizable.strings`.

- [ ] **Step 2: Generate and write `es-MX.lproj/Localizable.stringsdict`**

Copy the `.stringsdict` XML from `en.lproj` and replace the English strings with Spanish translations. Spanish plural rules: `one` (1) and `other` (0, 2+). Example:

```xml
<key>one</key>
<string>Selecciona %lld jugador que crees que está fingiendo</string>
<key>other</key>
<string>Selecciona %lld jugadores que crees que están fingiendo</string>
```

- [ ] **Step 3: Generate and write `es-ES.lproj/Localizable.strings`**

Translate all keys into Spain Spanish. Differences from es-MX:
- Use `vosotros` forms where applicable in instructions
- `"onboarding.hero_cta"` = `"¡A Jugar!"`
- `"loader.tagline"` = `"ENCUENTRA  •  ACUSA  •  SOBREVIVE"`

- [ ] **Step 4: Generate and write `es-ES.lproj/Localizable.stringsdict`** (same plural structure as es-MX)

- [ ] **Step 5: Generate and write `pt-BR.lproj/Localizable.strings`**

Translate all keys into Brazilian Portuguese. Key notes:
- `"role_reveal.imposter_label"` = `"IMPOSTOR"`
- `"loader.imposter_word"` = `"IMPOSTOR"`
- `"loader.tagline"` = `"ENCONTRE  •  ACUSE  •  SOBREVIVA"`
- `"voting.title"` = `"Quem é o Impostor?"`
- Use informal `você` throughout

- [ ] **Step 6: Generate `pt-BR.lproj/Localizable.stringsdict`** — Portuguese plural rules: one (1), other (0, 2+).

- [ ] **Step 7: Generate and write `fr.lproj/Localizable.strings`**

Translate all keys into French. Key notes:
- `"role_reveal.imposter_label"` = `"IMPOSTEUR"`
- `"loader.imposter_word"` = `"IMPOSTEUR"`
- `"loader.tagline"` = `"TROUVE  •  ACCUSE  •  SURVIE"`
- `"voting.title"` = `"Qui est l'Imposteur?"`
- French uses `"game_settings.play"` = `"JOUER"`
- Keep French punctuation rules (space before `:` `?` `!` — use `\u00A0` non-breaking space in `.strings`)

- [ ] **Step 8: Generate `fr.lproj/Localizable.stringsdict`** — French plural: 0 and 1 are "one", 2+ are "other".

- [ ] **Step 9: Generate and write `it.lproj/Localizable.strings`**

Translate all keys into Italian. Key notes:
- `"role_reveal.imposter_label"` = `"IMPOSTORE"`
- `"loader.imposter_word"` = `"IMPOSTORE"`
- `"loader.tagline"` = `"TROVA  •  ACCUSA  •  SOPRAVVIVI"`
- `"voting.title"` = `"Chi è l'Impostore?"`

- [ ] **Step 10: Generate `it.lproj/Localizable.stringsdict`** — Italian plural: one (1), other (all others).

- [ ] **Step 11: Build and commit**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded|FAILED"
git add ImposterGame/es-MX.lproj/ ImposterGame/es-ES.lproj/ ImposterGame/pt-BR.lproj/ ImposterGame/fr.lproj/ ImposterGame/it.lproj/
git commit -m "feat: add Romance language UI translations (es-MX, es-ES, pt-BR, fr, it)"
```

---

### Task 13: Germanic language UI translations (de, nl, sv, no)

**Files:** `ImposterGame/de.lproj/`, `ImposterGame/nl.lproj/`, `ImposterGame/sv.lproj/`, `ImposterGame/no.lproj/` — both `.strings` and `.stringsdict` for each.

- [ ] **Step 1: Generate `de.lproj/Localizable.strings`**

Translate all keys into German. Key notes:
- `"role_reveal.imposter_label"` = `"HOCHSTAPLER"`
- `"loader.imposter_word"` = `"HOCHSTAPLER"`
- `"loader.tagline"` = `"FINDE  •  BESCHULDIGE  •  ÜBERLEBE"`
- `"voting.title"` = `"Wer ist der Hochstapler?"`
- `"game_settings.play"` = `"SPIELEN"`
- German capitalizes all nouns — ensure noun translations are capitalized

- [ ] **Step 2: Generate `de.lproj/Localizable.stringsdict`** — German plural: one (1), other (all others).

- [ ] **Step 3: Generate `nl.lproj/Localizable.strings`**

Translate all keys into Dutch. Key notes:
- `"role_reveal.imposter_label"` = `"BEDRIEGER"`
- `"loader.imposter_word"` = `"BEDRIEGER"`
- `"loader.tagline"` = `"ZOEK  •  BESCHULDIG  •  OVERLEEFD"`

- [ ] **Step 4: Generate `nl.lproj/Localizable.stringsdict`** — Dutch plural: one (1), other (all others).

- [ ] **Step 5: Generate `sv.lproj/Localizable.strings`**

Translate all keys into Swedish. Key notes:
- `"role_reveal.imposter_label"` = `"BEDRAGAREN"`
- `"loader.imposter_word"` = `"BEDRAGARE"`
- `"loader.tagline"` = `"HITTA  •  ANKLAGA  •  ÖVERLEV"`

- [ ] **Step 6: Generate `sv.lproj/Localizable.stringsdict`** — Swedish plural: en (1), other (all others).

- [ ] **Step 7: Generate `no.lproj/Localizable.strings`**

Translate all keys into Norwegian Bokmål. Key notes:
- `"role_reveal.imposter_label"` = `"BEDRAGEREN"`
- `"loader.imposter_word"` = `"BEDRAGER"`
- `"loader.tagline"` = `"FINN  •  ANKLAGE  •  OVERLEV"`

- [ ] **Step 8: Generate `no.lproj/Localizable.stringsdict`** — Norwegian plural: en (1), other (all others).

- [ ] **Step 9: Build and commit**

```bash
git add ImposterGame/de.lproj/ ImposterGame/nl.lproj/ ImposterGame/sv.lproj/ ImposterGame/no.lproj/
git commit -m "feat: add Germanic language UI translations (de, nl, sv, no)"
```

---

### Task 14: Eastern European UI translations (pl, cs, hu, ro, el, uk)

**Files:** One `.strings` + one `.stringsdict` per locale.

- [ ] **Step 1: Generate `pl.lproj/Localizable.strings`**

Polish — `"role_reveal.imposter_label"` = `"OSZUST"`, `"loader.tagline"` = `"ZNAJDŹ  •  OSKARŻ  •  PRZEŻYJ"`.

- [ ] **Step 2: Generate `pl.lproj/Localizable.stringsdict`**

Polish has 4 plural categories. `voting.select_count` example:
- `one` (1): `"Wybierz %lld gracza, który udaje"` 
- `few` (2-4, 22-24...): `"Wybierz %lld graczy, którzy udają"`
- `many` (5-21, 25-31...): `"Wybierz %lld graczy, którzy udają"`
- `other`: same as many

NSStringPluralRuleType supports: zero, one, two, few, many, other. Use all that apply.

- [ ] **Step 3: Generate `cs.lproj/Localizable.strings`**

Czech — `"role_reveal.imposter_label"` = `"PODVODNÍK"`, `"loader.tagline"` = `"NAJDI  •  OBVINIT  •  PŘEŽIJ"`.

- [ ] **Step 4: Generate `cs.lproj/Localizable.stringsdict`** — Czech: one (1), few (2-4), many (5+), other.

- [ ] **Step 5: Generate `hu.lproj/Localizable.strings`**

Hungarian — `"role_reveal.imposter_label"` = `"MEGSZEMÉLYESÍTŐ"` (or `"BECSAPÓ"` — shorter), `"loader.tagline"` = `"KERESD  •  VÁDOLD  •  MARADJ ÉLETBEN"`.

- [ ] **Step 6: Generate `hu.lproj/Localizable.stringsdict`** — Hungarian: one (1), other (all others).

- [ ] **Step 7: Generate `ro.lproj/Localizable.strings`**

Romanian — `"role_reveal.imposter_label"` = `"IMPOSTOR"`, `"loader.tagline"` = `"GĂSEȘTE  •  ACUZĂ  •  SUPRAVIEȚUIEȘTE"`.

- [ ] **Step 8: Generate `ro.lproj/Localizable.stringsdict`** — Romanian: one (1), few (2-19), other (20+).

- [ ] **Step 9: Generate `el.lproj/Localizable.strings`**

Greek — `"role_reveal.imposter_label"` = `"ΑΠΑΤΕΩΝΑΣ"`, `"loader.tagline"` = `"ΒΡΕΣ  •  ΚΑΤΗΓΌΡΗΣΕ  •  ΕΠΙΒΊΩΣΕ"`.

- [ ] **Step 10: Generate `el.lproj/Localizable.stringsdict`** — Greek: one (1), other (all others).

- [ ] **Step 11: Generate `uk.lproj/Localizable.strings`**

Ukrainian — `"role_reveal.imposter_label"` = `"САМОЗВАНЕЦЬ"`, `"loader.tagline"` = `"ЗНАЙДИ  •  ЗВИНУВАТИ  •  ВИЖИ"`.

- [ ] **Step 12: Generate `uk.lproj/Localizable.stringsdict`** — Ukrainian: one (1), few (2-4), many (5+), other.

- [ ] **Step 13: Build and commit**

```bash
git add ImposterGame/pl.lproj/ ImposterGame/cs.lproj/ ImposterGame/hu.lproj/ ImposterGame/ro.lproj/ ImposterGame/el.lproj/ ImposterGame/uk.lproj/
git commit -m "feat: add Eastern European UI translations (pl, cs, hu, ro, el, uk)"
```

---

### Task 15: Middle East UI translations (ar, tr)

**Files:** `ImposterGame/ar.lproj/`, `ImposterGame/tr.lproj/`

- [ ] **Step 1: Generate `ar.lproj/Localizable.strings`**

Arabic — `"role_reveal.imposter_label"` = `"المخادع"`, `"loader.tagline"` = `"اكتشف  •  اتهم  •  انجُ"`. Write all strings in Arabic script. Format specifiers (`%lld`, `%@`) remain ASCII in the file — iOS handles bidirectional rendering.

- [ ] **Step 2: Generate `ar.lproj/Localizable.stringsdict`**

Arabic has 6 plural categories: zero, one, two, few (3-10), many (11-99), other. For `voting.select_count` provide all 6 forms.

- [ ] **Step 3: Generate `tr.lproj/Localizable.strings`**

Turkish — `"role_reveal.imposter_label"` = `"SAHTEKAR"`, `"loader.tagline"` = `"BUL  •  SUÇLA  •  HAYATTA KAL"`, `"voting.title"` = `"Sahtekar Kim?"`.

- [ ] **Step 4: Generate `tr.lproj/Localizable.stringsdict`** — Turkish: one (1), other (all others).

- [ ] **Step 5: Build and commit**

```bash
git add ImposterGame/ar.lproj/ ImposterGame/tr.lproj/
git commit -m "feat: add Arabic and Turkish UI translations"
```

---

### Task 16: Southeast and South Asian UI translations (id, vi, th)

**Files:** `ImposterGame/id.lproj/`, `ImposterGame/vi.lproj/`, `ImposterGame/th.lproj/`

- [ ] **Step 1: Generate `id.lproj/Localizable.strings`**

Indonesian — `"role_reveal.imposter_label"` = `"PENIPU"`, `"loader.tagline"` = `"TEMUKAN  •  TUDUH  •  SELAMAT"`.

- [ ] **Step 2: Generate `id.lproj/Localizable.stringsdict`** — Indonesian: no grammatical plural; use `other` for all.

- [ ] **Step 3: Generate `vi.lproj/Localizable.strings`**

Vietnamese — `"role_reveal.imposter_label"` = `"KẺ GIẢ MẠO"`, `"loader.tagline"` = `"TÌM  •  TỐ CÁO  •  SỐNG SÓT"`.

- [ ] **Step 4: Generate `vi.lproj/Localizable.stringsdict`** — Vietnamese: no grammatical plural; use `other` for all.

- [ ] **Step 5: Generate `th.lproj/Localizable.strings`**

Thai — `"role_reveal.imposter_label"` = `"ผู้แอบอ้าง"`, `"loader.tagline"` = `"หา  •  กล่าวหา  •  รอด"`.

- [ ] **Step 6: Generate `th.lproj/Localizable.stringsdict`** — Thai: no grammatical plural; use `other` for all.

- [ ] **Step 7: Build and commit**

```bash
git add ImposterGame/id.lproj/ ImposterGame/vi.lproj/ ImposterGame/th.lproj/
git commit -m "feat: add Indonesian, Vietnamese, Thai UI translations"
```

---

### Task 17: East Asian UI translations (ja, ko, zh-Hans)

**Files:** `ImposterGame/ja.lproj/`, `ImposterGame/ko.lproj/`, `ImposterGame/zh-Hans.lproj/`

- [ ] **Step 1: Generate `ja.lproj/Localizable.strings`**

Japanese — `"role_reveal.imposter_label"` = `"インポスター"` (katakana; or `"詐欺師"` kanji). Use `"インポスター"` for brand consistency. `"loader.tagline"` = `"見つけろ  •  告発しろ  •  生き残れ"`.

- [ ] **Step 2: Generate `ja.lproj/Localizable.stringsdict`** — Japanese: no grammatical plural; `other` only.

- [ ] **Step 3: Generate `ko.lproj/Localizable.strings`**

Korean — `"role_reveal.imposter_label"` = `"임포스터"`, `"loader.tagline"` = `"찾아라  •  고발하라  •  살아남아라"`.

- [ ] **Step 4: Generate `ko.lproj/Localizable.stringsdict`** — Korean: no grammatical plural; `other` only.

- [ ] **Step 5: Generate `zh-Hans.lproj/Localizable.strings`**

Simplified Chinese — `"role_reveal.imposter_label"` = `"内鬼"`, `"loader.tagline"` = `"找出  •  指控  •  生存"`, `"voting.title"` = `"谁是内鬼？"`.

- [ ] **Step 6: Generate `zh-Hans.lproj/Localizable.stringsdict`** — Chinese: no grammatical plural; `other` only.

- [ ] **Step 7: Build and commit**

```bash
git add ImposterGame/ja.lproj/ ImposterGame/ko.lproj/ ImposterGame/zh-Hans.lproj/
git commit -m "feat: add Japanese, Korean, Simplified Chinese UI translations"
```

---

### Task 18: English variant (en-GB)

**Files:** `ImposterGame/en-GB.lproj/Localizable.strings` + `.stringsdict`

- [ ] **Step 1: Copy `en.lproj/Localizable.strings` to `en-GB.lproj/` and apply British spelling differences**

Key differences from en-US:
- `"colour"` not `"color"` (no instances in current strings — no changes needed)
- `"Organised"` not `"Organized"` (no instances currently — no changes needed)
- `"loader.tagline"` = `"FIND  •  ACCUSE  •  SURVIVE"` (identical — British English keeps same tagline)
- All strings are identical to en-US for this app's content — `en-GB.lproj/Localizable.strings` can be a copy of `en.lproj`

- [ ] **Step 2: Copy stringsdict**

```bash
cp "ImposterGame/en.lproj/Localizable.strings" "ImposterGame/en-GB.lproj/Localizable.strings"
cp "ImposterGame/en.lproj/Localizable.stringsdict" "ImposterGame/en-GB.lproj/Localizable.stringsdict"
```

- [ ] **Step 3: Build and commit**

```bash
git add ImposterGame/en-GB.lproj/
git commit -m "feat: add en-GB locale (matches en-US for current string set)"
```

---

## Phase 4 — Word Pack Localization (8 Packs × 24 Locales)

> **Rules for every word pack JSON generated in this phase:**
> 1. Schema must match `WordPack` exactly: `category`, `icon`, `description`, `isPremium`, `words`, `imposterHints`
> 2. `words.count` MUST equal `imposterHints.count` — enforced in Task 26 validation
> 3. `imposterHints[i]` must be a 2-3 word vague clue for `words[i]` — enough for the imposter to guess the category without naming the word
> 4. Aim for ~65 words per pack (same count as English source)
> 5. Cultural adaptation: replace culturally irrelevant words with locale-appropriate equivalents (see per-pack notes below)
> 6. `icon` and `isPremium` values are copied verbatim from English — do not change
> 7. Use the target language script throughout (no mixing Latin script in CJK packs, etc.)

---

### Task 19: `party_time.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/party_time.json` (65 words)  
**Output:** `ImposterGame/Resources/WordPacks/{locale}/party_time.json` for all 24 locale folders

- [ ] **Step 1: Cultural adaptation notes per locale family**

**All locales — keep these universal words (translated):** Balloon, DJ, Cake, Dance floor, Confetti, Karaoke, Playlist, Champagne, Fireworks, Gift, Photo booth, Microphone, Cocktail, Toast, Selfie, Costume, Glitter, Bouncer, Afterparty, Nightclub

**Replace or add culturally:**
- `es-MX`: Add Quinceañera, Piñata (keep), Mariachi, Cumbia, Mezcal, Pirotecnia (fireworks), Tamalada, XV años
- `es-ES`: Add Verbena, Sevillanas, Sidra, Falla, Botellón, Chiringuito
- `pt-BR`: Add Carnaval, Forró, Caipirinha, Bloco, Samba, Frevo, Funk carioca
- `de`: Add Oktoberfest, Biergarten, Schunkeln, Prosit, Maßkrug, Volksfest, Feuerwerk
- `fr`: Add Apéritif, Boîte de nuit, Bal, Kir royal, Pétanque, Fête foraine
- `it`: Add Sagra, Piazza, Aperitivo, Tombola, Ferragosto, Brindisi
- `tr`: Add Eğlence, Meze, Rakı, Köy düğünü, Nişan, Sünnet düğünü
- `ar`: Add حفلة زفاف (wedding), عيد (Eid party), زفة (wedding procession), كنافة (sweets) — keep Islamic-appropriate items; remove alcohol-related words; add Eid, Ramadan celebration items
- `uk`: Add Вечорниці (folk evening), Хоровод, Борщ party, Варення, Свято
- `pl`: Add Andrzejki, Sylwester, Kulig, Chrzciny, Komunia, Osiemnastka
- `cs`: Add Masopust, Babský bál, Čepobití, Svíčková, Párty v hostinci
- `hu`: Add Szüret, Farsang, Bál, Pálinka, Majális, Búcsú
- `ro`: Add Revelion, Mici (BBQ), Hora, Nuntă, Petrecere câmpenească
- `el`: Add Πανηγύρι (panegyri), Ζεϊμπέκικο (dance), Ουζερί, Κεράσι (treat), Τσάμπα
- `id`: Add Arisan, Kenduri, Pesta kebun, Tumpeng, Dangdut, Karaoke keluarga
- `vi`: Add Tiệc tất niên, Lễ hội, Karaoke phòng, Nhậu, Bánh sinh nhật
- `th`: Add งานวัด (temple fair), สงกรานต์ (Songkran), ลอยกระทง, ปาร์ตี้น้ำ, เต้นสาวแล้ว
- `ja`: Add 花見 (hanami), 祭り (matsuri), 盆踊り, 忘年会 (bonenkai), 新年会, 縁日
- `ko`: Add 회식 (hoesik), 노래방 (noraebang), 치맥 (chicken + beer), 술자리, 파티, 생일파티
- `zh-Hans`: Add 派对, 卡拉OK, 圆桌饭, 烟花, 红包, 年夜饭, 庙会
- `nl`: Add Sinterklaas feest, Koningsdag, Borrel, Kroeg, Feestje, Vrijmibo
- `sv`: Add Midsommar, Jul, Surströmmingsparty, Fika, Kräftskiva, Fest
- `no`: Add Syttende mai, Julebord, Fest, Dugnad (community party), Hyttetur
- `en-GB`: Add Garden party, Bonfire Night, Boxing Day party, Pub quiz, Fancy dress, Rave

- [ ] **Step 2: For each locale, generate the complete `party_time.json` file**

Generate `ImposterGame/Resources/WordPacks/{locale}/party_time.json` for each of the 24 locale folders. Use the schema:

```json
{
  "category": "<translated party time>",
  "icon": "party.popper",
  "description": "<translated description ~15 words>",
  "isPremium": false,
  "words": ["<word1>", "<word2>", ... 65 words],
  "imposterHints": ["<hint1>", "<hint2>", ... 65 hints]
}
```

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add party_time.json for all 24 locales (culturally adapted)"
```

---

### Task 20: `food.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/food.json` (65 words)  
**Output:** `ImposterGame/Resources/WordPacks/{locale}/food.json`

- [ ] **Step 1: Cultural adaptation notes**

**Universal (keep, translated):** Ice cream, Pizza, Sushi, Pasta, Burger, Salad, Soup, Chocolate, Bread, Rice, Egg, Bacon, Waffle, Pancake, Salmon, Cookie, Cake

**Replace or add:**
- `es-MX`: Add Tacos, Enchiladas, Pozole, Tamales, Chiles rellenos, Guacamole, Elote, Churros, Quesadilla, Mole; remove Lobster (replace with Camarones), Croissant
- `es-ES`: Add Paella, Gazpacho, Tortilla española, Jamón, Churros, Croquetas, Pulpo, Fabada, Cocido madrileño
- `pt-BR`: Add Feijoada, Coxinha, Brigadeiro, Açaí, Picanha, Pão de queijo, Caipirinha food, Tapioca, Churrasco
- `de`: Add Bratwurst, Sauerkraut, Bretzel, Schnitzel, Leberwurst, Currywurst, Maultaschen, Strudel, Käsekuchen
- `fr`: Add Baguette, Brie, Croissant (keep), Crêpe, Escargot, Foie gras, Ratatouille, Soupe à l'oignon, Macarons, Tarte tatin
- `it`: Add Risotto, Tiramisù, Prosciutto, Mozzarella, Parmigiano, Carbonara, Gnocchi, Panettone, Espresso
- `tr`: Add Döner, Baklava, Çiğ köfte, Ayran, Börek, Simit, Meze, Kebap, Pide, Lahmacun
- `ar`: Add Mansaf, Shawarma, Falafel, Hummus, Kabsa, Knafeh, Luqaimat, Harees, Tabbouleh, Fattoush; remove pork/alcohol items
- `uk`: Add Борщ, Вареники, Сало, Галушки, Голубці, Деруни, Пампушки, Медівник, Узвар, Ковбаса
- `pl`: Add Pierogi, Bigos, Żurek, Kiełbasa, Gołąbki, Oscypek, Flaki, Barszcz, Makowiec, Sernik
- `cs`: Add Svíčková, Knedlíky, Guláš, Trdelník, Smažený sýr, Tatarák, Chlebíčky, Klobása, Buchtičky
- `hu`: Add Gulyás, Lángos, Kürtőskalács, Túrós táska, Halászlé, Lecsó, Hurka, Dobos torta, Paprikás csirke
- `ro`: Add Mămăligă, Sarmale, Mici, Cozonac, Ciorba, Tochiturǎ, Papanași, Salată de boeuf, Plăcintă
- `el`: Add Souvlaki, Moussaka, Feta, Spanakopita, Baklava, Tzatziki, Dolmades, Loukoumades, Fasolia, Gigantes
- `id`: Add Nasi goreng, Rendang, Sate, Gado-gado, Bakso, Martabak, Soto, Opor ayam, Tempe, Kerupuk
- `vi`: Add Phở, Bánh mì, Nem, Bún bò, Chả giò, Bánh xèo, Cơm tấm, Chè, Bún chả, Gỏi cuốn
- `th`: Add ผัดไทย (Pad Thai), ต้มยำ (Tom Yum), แกงเขียวหวาน (Green curry), ส้มตำ (Som tam), ข้าวมันไก่, ลาบ, ยำ, มะม่วงข้าวเหนียว
- `ja`: Add 寿司, ラーメン, 天ぷら, 焼き鳥, おにぎり, 唐揚げ, 抹茶, たこ焼き, 味噌汁, 納豆, 牛丼, カレーライス
- `ko`: Add 김치, 비빔밥, 삼겹살, 떡볶이, 순두부찌개, 냉면, 치킨, 삼계탕, 잡채, 호떡, 붕어빵
- `zh-Hans`: Add 火锅, 饺子, 包子, 麻辣烫, 烤鸭, 小龙虾, 扬州炒饭, 粽子, 月饼, 汤圆, 红烧肉
- `nl`: Add Stroopwafel, Bitterballen, Stamppot, Haring, Poffertjes, Erwtensoep, Appeltaart, Kroket, Frikandel
- `sv`: Add Köttbullar, Gravlax, Kanelbullar, Surströmming, Smörgåstårta, Raggmunk, Janssons frestelse, Dillkött
- `no`: Add Brunost, Lutefisk, Rakfisk, Lefse, Raspeball, Kjøttkaker, Rømmegrøt, Pinnekjøtt, Smalahove
- `en-GB`: Add Fish and chips, Full English, Scones, Spotted dick, Jacket potato, Beans on toast, Bangers and mash, Yorkshire pudding, Eton mess

- [ ] **Step 2: Generate complete `food.json` for each of 24 locale folders**

Use the schema with `"icon": "fork.knife"` and `"isPremium": true`.

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add food.json for all 24 locales (culturally adapted)"
```

---

### Task 21: `family.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/family.json` (50 words, `isPremium: false`)

- [ ] **Step 1: Cultural adaptation — replace US-centric holidays and customs**

**Universal (translated):** Grandma, Dinner Table, Road Trip, Family Photo, Bedtime Story, Sibling Rivalry, Birthday Cake, Vacation, Wedding, Camping, Board Game Night

**Replace:**
- Remove: Thanksgiving, Prom Night (US-only)
- `es-MX/es-ES`: Add Día de Muertos, Posadas, Quinceañera, Compadre, Madrina, Padrino
- `pt-BR`: Add Festa junina, Carnaval em família, Vovó, Comadre
- `de`: Add Weihnachten, Ostern, Erntedankfest (harvest), Geburtstag, Oma, Opa, Faschingsdienstag
- `fr`: Add Noël en famille, Toussaint, Repas dominical, Mamie, Papi, Fête des mères
- `it`: Add Ferragosto, Pasqua in famiglia, Nonno, Nonna, Gita fuori porta, Prima Comunione
- `tr`: Add Ramazan Bayramı, Kurban Bayramı, Sünnet düğünü, Nişan, Bayramlık, Büyükanne
- `ar`: Add عيد الفطر, عيد الأضحى, رمضان, خطوبة, زفاف تقليدي, جدة, جد, وليمة, ختان
- `uk/pl/cs/hu/ro`: Replace with local holidays — Easter (Velykden/Wielkanoc/Velikonoce/Húsvét/Paști), local family traditions
- `el`: Add Πάσχα, Ονομαστική εορτή (name day), Θεία, Γιαγιά, Παπούς
- `ja`: Add お正月, お盆, 七五三, 成人式, 初詣, おじいちゃん, おばあちゃん, 法事
- `ko`: Add 추석 (Chuseok), 설날 (Seollal), 돌잔치, 회갑, 할머니, 할아버지
- `zh-Hans`: Add 春节, 清明节, 中秋节, 爷爷, 奶奶, 外公, 外婆, 压岁钱, 家宴
- `th`: Add สงกรานต์, วันพ่อ, วันแม่, ยาย, ตา, ปู่, ย่า, บวชพระ, งานบุญ
- `ja/ko/zh-Hans/th/vi/id`: Remove Christmas-specific references if not culturally primary; add local equivalents

- [ ] **Step 2: Generate `family.json` for all 24 locales** (schema: `"icon": "house.fill"`, `"isPremium": false`)

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add family.json for all 24 locales (culturally adapted)"
```

---

### Task 22: `movies.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/movies.json` (50 words, `isPremium: true`)

- [ ] **Step 1: Cultural adaptation — replace Oscar/Hollywood-centric items**

**Universal (translated):** Popcorn, Director, Plot Twist, Trailer, Villain, Sequel, Premiere, Subtitles, Soundtrack, Documentary, Zombie, Jump Scare, Binge Watch, Spoiler Alert

**Replace by locale:**
- `fr`: Replace Oscar → César Award; replace Hollywood → Cannes, Nouvelle Vague
- `it`: Replace Oscar → David di Donatello; add Commedia all'italiana, Spaghetti Western, Fellini (as concept)
- `de`: Replace Oscar → Lola (Deutscher Filmpreis); add Tatort (TV), Fassbinder era
- `es-MX`: Add Telenovela, Lucha libre movie, Cine de oro
- `es-ES`: Add Almódovar (as genre concept), Cine español
- `ja`: Replace Oscar → Japan Academy Award (日本アカデミー賞); add アニメ (Anime), 時代劇 (Jidaigeki), 映画館
- `ko`: Replace Oscar → Baeksang Arts Awards; add K-드라마, OTT, 좀비 영화
- `zh-Hans`: Add 香港电影 (HK cinema), 功夫片, 古装剧, 弹幕 (barrage comments)
- `ar`: Add مسلسل رمضاني (Ramadan series); remove content inappropriate for market
- `tr`: Add Yeşilçam (classic Turkish cinema), Dizi (TV series)
- All: Replace "Casting Couch" with a neutral term in all locales

- [ ] **Step 2: Generate `movies.json` for all 24 locales** (schema: `"icon": "film.fill"`, `"isPremium": true`)

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add movies.json for all 24 locales (culturally adapted)"
```

---

### Task 23: `music.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/music.json` (`isPremium: true`)

- [ ] **Step 1: Cultural adaptation — replace Grammy/US music awards**

**Universal:** DJ, Microphone, Concert, Playlist, Album, Lyrics, Music Video, Live show, Bass, Headphones, Melody, Rhythm, Chord, Remix, Acoustic

**Replace awards and genres:**
- `fr`: Grammy → Victoires de la Musique; add Chanson, Électro, Rap français
- `de`: Grammy → ECHO Musikpreis; add Schlager, Rammstein-style Metal, Techno (Berlin)
- `it`: Grammy → Wind Music Awards; add Opera, Sanremo, Melodia italiana
- `es-MX`: Add Banda, Norteño, Corrido, Regional Mexicano, Mariachi; Grammy → Latin Grammy
- `es-ES`: Add Flamenco, Rumba, Copla; Grammy → Premios Odeón
- `pt-BR`: Add Samba, Bossa Nova, Funk carioca, Forró, Axé; Grammy → Latin Grammy
- `tr`: Add Arabesk, Halk müziği, Türkü, TRT Radyo
- `ar`: Add موسيقى عربية, طرب, عود (oud instrument), موشح
- `ja`: Grammy → Japan Record Award; add J-POP, アイドル, カラオケ, 演歌, 和楽器
- `ko`: Grammy → Melon Music Awards; add K-POP, 아이돌, 음원차트, 뮤직쇼
- `zh-Hans`: Grammy → 华语音乐传媒大奖; add 民谣, 国风, 嘻哈, KTV, 综艺音乐
- `el`: Add Λαϊκά, Ρεμπέτικα, Σκυλάδικο
- `uk/pl`: Add folk music references

- [ ] **Step 2: Generate `music.json` for all 24 locales**

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add music.json for all 24 locales (culturally adapted)"
```

---

### Task 24: `places.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/places.json` (50 words, `isPremium: true`)

- [ ] **Step 1: Cultural adaptation — replace US-centric venues**

**Universal (translated):** Airport, Museum, Hospital, Beach, Library, Zoo, Stadium, Restaurant, Church/Mosque/Temple (adapt to locale religion), Train Station, Hotel, Market

**Replace by locale:**
- All locales: Remove `Drive-In Theater` (US-specific) → replace with local equivalent cinema type
- `de`: Add Biergarten, Autobahn, Schloss (castle), Weihnachtsmarkt
- `fr`: Add Boulangerie, Brasserie, Château, Marché provençal, Métro
- `ja`: Add 神社 (shrine), 温泉 (onsen), 居酒屋 (izakaya), 百貨店, パチンコ店
- `ko`: Add 찜질방, PC방, 한강공원, 재래시장, 노래방
- `zh-Hans`: Add 菜市场, 夜市, 网吧, 广场, 茶馆, 寺庙
- `ar`: Add المسجد, السوق, الحمام التركي, القصر, الكورنيش
- `tr`: Add Çarşı, Hamam, Camii, Çay evi, Sahil
- `es-MX`: Add Mercado (tianguis), Plaza mayor, Iglesia colonial, Taquería
- `id`: Add Warung, Pasar malam, Masjid, Pesantren, Alun-alun
- `in all locales`: Use culturally appropriate religious building term (Mosque for AR/TR/ID, Shrine for JA, Temple for TH/VI/ZH)

- [ ] **Step 2: Generate `places.json` for all 24 locales**

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add places.json for all 24 locales (culturally adapted)"
```

---

### Task 25: `sports.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/sports.json` (50 words, `isPremium: true`)

- [ ] **Step 1: Cultural adaptation — replace NFL/NBA with local sports**

**Universal:** Marathon, Trophy, Medal, Referee, Penalty, Yellow Card, Boxing Ring, Surfboard, Yoga Mat, Warm Up, Olympics

**Replace American sports:**
- Remove: Touchdown, Home Run, Draft Pick, Trade Deadline, Playoff, Championship Ring (NFL/MLB/NBA)
- Add `es-MX/es-ES/pt-BR/it/fr/de/nl`: La Liga, Serie A, Bundesliga, Ligue 1, Champions League, Copa del Mundo, Offside, Free kick, Header, Corner kick
- Add `de`: Bundesliga, DFB-Pokal, Biathlon, Ski jumping
- Add `fr`: Tour de France, Roland Garros, Rugby (XV), Pétanque
- Add `ja`: 野球 (baseball - major in Japan!), 相撲, J-League, 柔道, 剣道, 弓道
- Add `ko`: 야구 (baseball), K-League, 태권도, 씨름 (ssireum wrestling), E-sports
- Add `zh-Hans`: 乒乓球 (table tennis), 羽毛球, 篮球, 足球, 武术, 围棋
- Add `ar`: كرة القدم, كرة السلة, الملاكمة, رياضة الفروسية, سباق الإبل
- Add `tr`: Güreş (wrestling), Kılıç kalkan, Okçuluk, Süper Lig
- Add `in/id/vi/th`: Add cricket (IN), badminton (ID/VN), Muay Thai (TH), sepak takraw (TH/VN/ID)
- Add `uk/pl/cs/hu/ro/el`: Football-centric; add local sports (Ukrainian wrestling, Polish volleyball, Greek sailing)
- Add `sv/no`: Ice hockey, Biathlon, Cross-country skiing, Handball
- Add `nl`: Schaatsen (speed skating), Wielrennen (cycling), Field hockey

- [ ] **Step 2: Generate `sports.json` for all 24 locales**

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add sports.json for all 24 locales (culturally adapted)"
```

---

### Task 26: `spicy.json` — all 24 locales

**English source:** `ImposterGame/Resources/WordPacks/en/spicy.json` (50 words, `isPremium: true`)

- [ ] **Step 1: Cultural adaptation — sensitivity review per region**

**Universal (translated across all):** Blind Date, Love Letter, Crush, Heartbreak, Slow Dance, Candlelit Dinner, Massage, Jealousy, Ghosting, Chemistry, Butterflies, Soulmate, Date Night, Flirting, Kiss, Wink, Secret Admirer

**Regional sensitivity adjustments:**
- `ar`: Remove explicit content (Strip Poker, Skinny Dipping, Spin the Bottle, Seven Minutes, Walk of Shame, Body Shot, Friends with Benefits, Affair); replace with romance-adjacent but culturally appropriate: خطوبة (engagement), رسالة حب (love letter), لقاء سري (secret meeting), نظرة (glance), حب من بعيد (long-distance love)
- `tr`: Similar to AR but slightly less restrictive — remove most explicit; keep flirting, date concepts
- `id`: Remove explicit; keep romantic concepts
- `th/vi`: Keep most items; remove most explicit references
- `ja/ko`: Keep most items; add culturally relevant ones: バレンタイン (Valentine), 告白 (confession of love), 합석 (blind group date)
- All `eu` locales: Keep most English items, adapt phrasing; "Netflix and Chill" is universal

- [ ] **Step 2: Generate `spicy.json` for all 24 locales**

- [ ] **Step 3: Commit**

```bash
git add ImposterGame/Resources/WordPacks/
git commit -m "feat: add spicy.json for all 24 locales (culturally adapted with regional sensitivity)"
```

---

## Phase 5 — Validation and Integration Testing

### Task 27: JSON validation script

**Files:**
- Create: `scripts/validate_wordpacks.sh`

- [ ] **Step 1: Create the validation script**

Create `scripts/validate_wordpacks.sh`:

```bash
#!/usr/bin/env bash
set -e

PACKS_DIR="ImposterGame/Resources/WordPacks"
REQUIRED_LOCALIZED=("party_time" "food" "family" "movies" "music" "places" "sports" "spicy")
ALL_LOCALES=("en" "en-GB" "es-MX" "es-ES" "pt-BR" "de" "fr" "it" "tr" "ar" "uk" "pl" "cs" "hu" "ro" "el" "id" "vi" "th" "ja" "ko" "zh-Hans" "nl" "sv" "no")
ENGLISH_ONLY=("celebrities" "hobbies" "school" "shopping" "tech" "superpowers" "travel" "work_life")

ERRORS=0

echo "=== Validating English-only packs ==="
for pack in "${ENGLISH_ONLY[@]}"; do
  FILE="$PACKS_DIR/en/${pack}.json"
  if [ ! -f "$FILE" ]; then
    echo "MISSING: $FILE"
    ERRORS=$((ERRORS + 1))
  else
    python3 -c "import json,sys; d=json.load(open('$FILE')); assert len(d['words'])==len(d.get('imposterHints',[])), 'words/hints count mismatch'; print('OK: $FILE (' + str(len(d[\"words\"])) + ' words)')"
  fi
done

echo ""
echo "=== Validating localized packs ==="
for locale in "${ALL_LOCALES[@]}"; do
  for pack in "${REQUIRED_LOCALIZED[@]}"; do
    FILE="$PACKS_DIR/${locale}/${pack}.json"
    if [ ! -f "$FILE" ]; then
      echo "MISSING: $FILE"
      ERRORS=$((ERRORS + 1))
    else
      python3 -c "
import json, sys
with open('$FILE') as f:
    d = json.load(f)
words = d.get('words', [])
hints = d.get('imposterHints', [])
if len(words) != len(hints):
    print('MISMATCH: $FILE — words=' + str(len(words)) + ' hints=' + str(len(hints)))
    sys.exit(1)
if len(words) < 50:
    print('WARNING: $FILE — only ' + str(len(words)) + ' words (expected ~65)')
print('OK: $FILE (' + str(len(words)) + ' words)')
" || ERRORS=$((ERRORS + 1))
    fi
  done
done

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "✅ All word packs valid"
else
  echo "❌ $ERRORS error(s) found"
  exit 1
fi
```

- [ ] **Step 2: Make it executable and run it**

```bash
chmod +x scripts/validate_wordpacks.sh
bash scripts/validate_wordpacks.sh
```

Expected: `✅ All word packs valid` with OK lines for every file. Fix any `MISSING` or `MISMATCH` errors before proceeding.

- [ ] **Step 3: Validate Localizable.strings files**

```bash
for lproj in ImposterGame/*.lproj; do
  file="$lproj/Localizable.strings"
  if [ -f "$file" ] && [ -s "$file" ]; then
    plutil -lint "$file" && echo "OK: $file" || echo "INVALID: $file"
  fi
done
```

Expected: `OK:` for every non-empty `.strings` file.

- [ ] **Step 4: Commit the validation script**

```bash
git add scripts/
git commit -m "chore: add word pack validation script"
```

---

### Task 28: Simulator locale testing

- [ ] **Step 1: Test English (baseline)**

```bash
xcodebuild -project ImposterGame.xcodeproj -scheme ImposterGame \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|warning:|Build succeeded|FAILED"
```

Expected: `Build succeeded`, zero errors.

- [ ] **Step 2: Test Arabic (RTL) on simulator**

In Xcode: Product → Scheme → Edit Scheme → Run → Options → App Language: Arabic. Launch app in simulator. Verify:
- UI mirrors correctly (back button on right, content flows RTL)
- Arabic word pack loads (Categories screen shows Arabic category names)
- No layout overflow or clipping

- [ ] **Step 3: Test Japanese (CJK) on simulator**

Set App Language to Japanese. Verify:
- Category names show in Japanese script
- Loader animated word spells out the Japanese `loader.imposter_word` character-by-character
- Word pack content shows in Japanese

- [ ] **Step 4: Test Spanish — Mexico on simulator**

Set App Language to Spanish, Region to Mexico. Verify:
- UI shows Spanish strings
- Word packs load es-MX variants (not es-ES)
- Category loader resolves `es-MX` folder correctly

- [ ] **Step 5: Test locale fallback — Finnish (unsupported)**

Set App Language to Finnish (not in the 25 locales). Verify:
- App shows English UI
- Word packs load from `en/` folder
- No crash

- [ ] **Step 6: Test plural forms (Voting screen)**

With Arabic set as app language:
- Start a game with 1 imposter → verify singular Arabic form on voting screen
- Start a game with 2 imposters → verify dual form
- Start a game with 5 imposters → verify plural form

- [ ] **Step 7: Final build and commit**

```bash
git add -A
git commit -m "feat: complete 25-locale localization rollout — UI strings, word packs, validation"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** Infrastructure (Phase 1 tasks 1-3), UI extraction (Phase 2, tasks 4-11), UI translation (Phase 3, tasks 12-18), Word packs (Phase 4, tasks 19-26), validation (Phase 5, tasks 27-28). All 5 spec phases covered.
- [x] **Placeholder scan:** All tasks contain exact code, exact commands, or exact cultural adaptation directives. No TBDs.
- [x] **Type consistency:** `CategoryLoader.resolvedLocaleFolders()` defined in Task 2 → used in same file. `LocalizedStringKey` pattern consistent across all View tasks. `WordPack` schema in Tasks 19-26 matches `Category.swift` Codable struct.
- [x] **BCP-47 fix:** `Locale.current.region?.identifier` issue addressed — the `overrides` dict in `resolvedLocaleFolders()` handles `es-419`, `zh-CN`, `nb-NO` explicitly.
- [x] **Analytics preserved:** `AnalyticsService.logEvent("category_load_failed", ...)` kept and enhanced with `locale_folder` parameter in Task 2.
- [x] **en-GB word packs:** Covered in Tasks 19-26 with British food/party/sports adaptations.
- [x] **Arabic sensitivity:** Covered in Tasks 26 (spicy) and 15 (ar UI strings) with sensitivity notes.
- [x] **XcodeGen:** `project.yml` updated in Task 3 to set `developmentLanguage: en` and `LOCALIZATION_PREFERS_STRING_CATALOGS: NO`.
