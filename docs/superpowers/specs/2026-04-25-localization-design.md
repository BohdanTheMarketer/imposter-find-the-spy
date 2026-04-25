# Localization Design — Imposter: Find the Spy
**Date:** 2026-04-25  
**Scope:** Full 25-locale rollout — UI strings + 8 culturally-adapted word packs + imposter hints

---

## 1. Supported Locales

| Locale Code | Region / Notes |
|---|---|
| `en` | English — US (base development locale) |
| `en-GB` | English — UK |
| `es-MX` | Spanish — Mexico / LATAM |
| `es-ES` | Spanish — Spain |
| `pt-BR` | Portuguese — Brazil |
| `de` | German |
| `fr` | French |
| `it` | Italian |
| `tr` | Turkish |
| `ar` | Arabic (RTL; KSA / UAE) |
| `uk` | Ukrainian |
| `pl` | Polish |
| `cs` | Czech |
| `hu` | Hungarian |
| `ro` | Romanian |
| `el` | Greek |
| `id` | Indonesian |
| `vi` | Vietnamese |
| `th` | Thai |
| `ja` | Japanese |
| `ko` | Korean |
| `zh-Hans` | Simplified Chinese |
| `nl` | Dutch |
| `sv` | Swedish |
| `no` | Norwegian |

**Not included:** RU-RU (excluded per product decision).

---

## 2. Architecture — Two Parallel Systems

### 2.1 UI Strings — `Localizable.strings`

Standard Apple localization via `.lproj` directories:

```
ImposterGame/Resources/
  en.lproj/
    Localizable.strings          ← base English (~100 keys)
  es-MX.lproj/
    Localizable.strings
  fr.lproj/
    Localizable.strings
  … (one .lproj folder per locale, 25 total)
```

- SwiftUI `Text("key")` resolves via `LocalizedStringKey` automatically.
- Non-Text contexts (error alerts, format strings) use `NSLocalizedString("key", comment: "")` or `String(localized: "key")`.
- Format strings use `%lld` (integer) and `%@` (string) placeholders, matching `String(format:)` calls.
- The base `en.lproj/Localizable.strings` is the source of truth; all other locales are derived from it.

**Arabic (RTL):** No layout changes needed in SwiftUI — the framework handles RTL mirroring automatically. Translators should use Arabic numerals for integers in that locale.

### 2.2 Word Packs — Locale-Folder JSON

```
ImposterGame/Resources/WordPacks/
  en/                            ← all 16 English JSON packs live here
    party_time.json
    food.json
    family.json
    movies.json
    music.json
    places.json
    sports.json
    spicy.json
    celebrities.json             ← English-only fallback packs (8)
    hobbies.json
    school.json
    shopping.json
    tech.json
    superpowers.json
    travel.json
    work_life.json

  es-MX/                         ← 8 culturally-adapted packs per locale
    party_time.json
    food.json
    family.json
    movies.json
    music.json
    places.json
    sports.json
    spicy.json

  fr/  de/  it/  pt-BR/  es-ES/
  tr/  ar/  uk/  pl/  cs/  hu/
  ro/  el/  id/  vi/  th/  ja/
  ko/  zh-Hans/  nl/  sv/  no/
  en-GB/
    … same 8 localized packs …
```

**English-only packs** (celebrities, hobbies, school, shopping, tech, superpowers, travel, work_life) live **only** in `en/`. `CategoryLoader` falls back to `en/` when a locale-specific file is not found — zero crash risk.

---

## 3. `CategoryLoader` Changes

### 3.1 Locale resolution

```swift
private static func resolvedLocaleFolder() -> [String] {
    let locale = Locale.current
    let lang   = locale.language.languageCode?.identifier ?? "en"
    let region = locale.region?.identifier ?? ""
    let full   = region.isEmpty ? lang : "\(lang)-\(region)"

    // Ordered preference: exact (e.g. "es-MX") → language-only (e.g. "es") → "en"
    // Note: there is no plain "es/" folder — es-MX and es-ES each have their own folder.
    // If neither exact nor language-only folder exists, we fall through to "en".
    if full == lang {
        return [lang, "en"]
    } else {
        return [full, lang, "en"]   // lang step will miss for es/pt/zh-Hans etc. → falls to en
    }
}
```

### 3.2 Loading logic

```swift
static func loadCategories() -> [Category] {
    let candidates = resolvedLocaleFolder()
    return fileNames.compactMap { fileName in
        for folder in candidates {
            if let url = Bundle.main.url(
                forResource: fileName,
                withExtension: "json",
                subdirectory: "WordPacks/\(folder)"
            ) {
                return decode(url: url)
            }
        }
        return nil
    }
}
```

- `Bundle.main.url(forResource:withExtension:subdirectory:)` does not require Xcode localization entries for subdirectory-based lookup — it works purely on the file system layout inside the bundle.
- The existing `defaultCategories()` fallback remains intact for catastrophic failures.

### 3.3 Xcode project changes

- Move existing JSON files from `Resources/WordPacks/*.json` → `Resources/WordPacks/en/*.json` in both the file system **and** the Xcode project (update `project.pbxproj` / `project.yml` to reference the new paths).
- Add the new locale JSON files to the Xcode project under the app target (Copy Bundle Resources phase).
- Add `.lproj` folders to Xcode's Localizations list (Project settings → Info → Localizations) for each of the 25 locales.

---

## 4. UI String Keys (~100 Keys)

### 4.1 Complete key inventory

#### Common (reused across views)
```
common.back                   = "Back"
common.ok                     = "OK"
common.close                  = "Close"
common.next                   = "Next"
common.continue               = "Continue"
common.coming_soon            = "Coming soon"
common.got_it                 = "Got It!"
```

#### Legal
```
legal.privacy_policy          = "Privacy Policy"
legal.terms                   = "Terms & Conditions"
legal.terms_short             = "Terms"
legal.privacy_short           = "Privacy"
```

#### GameSettingsView
```
game_settings.title                       = "Game Settings"
game_settings.play                        = "PLAY"
game_settings.imposter_count_singular     = "Imposter"
game_settings.imposter_count_plural       = "Imposters"
game_settings.imposters_section_title     = "Imposters"
game_settings.imposters_help              = "How many players should be secret imposters?"
game_settings.imposters_recommended_format = "Recommended for %lld players: %lld"
game_settings.round_duration_title        = "Round Duration"
game_settings.round_duration_help         = "How long should each discussion round last?"
game_settings.hints_title                 = "Hints for Imposters"
game_settings.hints_help                  = "Should imposters get a hint about the secret word?"
game_settings.hints_disabled              = "Disabled"
game_settings.hints_enabled               = "Enabled"
game_settings.word_load_error             = "Couldn't load a word for this category. Please try again."
```

#### PlayerSetupView
```
player_setup.title                        = "Players"
player_setup.name_placeholder             = "Enter player name"
player_setup.continue                     = "CONTINUE"
player_setup.player_count_singular        = "Player"
player_setup.player_count_plural_suffix   = "s"
player_setup.minimum_players_hint         = "Minimum 3 players to start a game"
player_setup.options_title                = "Options"
player_setup.options_language             = "Language"
player_setup.options_contact              = "Contact Us"
player_setup.udid_loading                 = "Loading…"
player_setup.udid_unavailable             = "Unavailable"
player_setup.udid_label                   = "UDID:"
player_setup.udid_toast_loading           = "UDID is still loading. Try again in a moment."
player_setup.udid_toast_unavailable       = "UDID is unavailable right now."
player_setup.udid_toast_copied            = "UDID copied"
player_setup.udid_toast_copy_failed       = "Could not copy UDID"
```

#### RoleRevealView
```
role_reveal.unknown_player                = "Unknown"
role_reveal.imposter_lead_in              = "You are the"
role_reveal.imposter_label                = "IMPOSTER"
role_reveal.hint_title                    = "Imposter hint"
role_reveal.crew_secret_prefix            = "Your secret word is:"
role_reveal.all_done                      = "Everyone has seen the word"
role_reveal.pass_phone_format             = "Pass the phone to %@"
role_reveal.start_game                    = "Start Game"
role_reveal.swipe_instruction             = "Swipe up to reveal\nthe secret word"
```

#### VotingView
```
voting.title                              = "Who's the Imposter?"
voting.select_count_singular              = "Select %lld player"
voting.select_count_plural                = "Select %lld players"
voting.selected_count_format              = "%lld/%lld selected"
voting.reveal                             = "Reveal"
```

#### ResultView
```
result.intrigue_the                       = "THE"
result.intrigue_moment                    = "MOMENT"
result.intrigue_of                        = "OF"
result.intrigue_truth                     = "TRUTH"
result.title_players_win                  = "Players Win!"
result.title_imposter_wins                = "Imposter Wins!"
result.subtitle_single_caught             = "The imposter was caught"
result.subtitle_two_caught                = "Both imposters caught"
result.subtitle_all_caught_format         = "All %lld imposters caught"
result.subtitle_imposter_escaped          = "They got away undetected"
result.badge_players_won                  = "Players won"
result.badge_imposter_won                 = "Imposter won"
result.screen_title                       = "Results"
result.secret_word_label                  = "SECRET WORD"
result.play_again                         = "PLAY AGAIN"
result.no_imposter                        = "No imposter found"
```

#### OnboardingView
```
onboarding.page2_title                    = "Instant Fun\nAnywhere!"
onboarding.page2_subtitle                 = "Game night, road trip, or\neven an awkward first meeting —\nFakeit breaks the ice and\nbrings the fun"
onboarding.page2_cta                      = "I'm In!"
onboarding.page3_title                    = "Who's Faking It?"
onboarding.page3_subtitle                 = "One of you is lying.\nThe rest know the word.\nCan you spot the imposter\nbefore it's too late?"
onboarding.page3_cta                      = "Got It"
onboarding.hero_talk_smarter              = "Talk Smarter"
onboarding.hero_guess_better              = "Guess Better"
onboarding.hero_body                      = "Describe the secret word without saying it.\nBut beware — the imposter is listening and trying to blend in"
onboarding.hero_cta                       = "Let's Play!"
```

#### GameTimerView
```
game_timer.starts_asking                  = "Starts Asking!"
game_timer.section_label                  = "Timer"
game_timer.paused                         = "Paused"
game_timer.vote_now                       = "Vote Now"
game_timer.pause                          = "Pause"
```

#### PaywallView / CategoryPaywallView
```
paywall.headline                          = "Continue to get\nfull access"
paywall.plan_yearly                       = "Yearly"
paywall.plan_weekly                       = "Weekly"
paywall.cancel_anytime                    = "Cancel anytime"
paywall.badge_best_value                  = "Best value"
paywall.badge_most_popular                = "Most popular"
paywall.trial_prompt_title                = "Not sure yet?"
paywall.trial_prompt_subtitle             = "Enable free access"
paywall.trial_legal_line                  = "0 USD due today • 3 days FREE"
paywall.continue                          = "Continue"
paywall.skip                              = "Skip"
paywall.restore                           = "Restore"
paywall.restore_alert_title               = "Restore Purchases"
paywall.restore_alert_message             = "If you have an active subscription, it will be restored shortly."
category_paywall.free_access_on           = "Free access enabled"
category_paywall.trial_on_subtitle        = "No commitment, cancel anytime"
category_paywall.cta_trial                = "Try it for Free"
```

#### CategoriesView
```
categories.title                          = "Categories"
categories.play                           = "Play"
categories.selection_count_label          = "Category"
categories.info.step1_title               = "Choose Your Themes"
categories.info.step1_subtitle            = "Pick one or more themes to set the mood and match your vibe and party."
categories.info.step2_title               = "Drop a Clue"
categories.info.step2_subtitle            = "Give a clever hint or association. Clear for those in the know - confusing for the imposter."
categories.info.step3_title               = "Check Your Role"
categories.info.step3_subtitle            = "Everyone sees the secret word... except the imposter - they only see their role. Their goal? Blend in."
categories.info.step4_title               = "Time to Vote"
categories.info.step4_subtitle            = "Talk's over. Now vote to expose the imposter!"
categories.info.vote_win                  = "✅  Guess right - you win"
categories.info.vote_lose                 = "❌  Miss - imposter wins"
categories.info.instant_win_warning       = "⚠️ If the imposter guesses the word before time runs out, they win instantly"
```

#### LoaderView
```
loader.tagline                            = "FIND  •  ACCUSE  •  SURVIVE"
loader.imposter_word                      = "IMPOSTER"
```
*Note: The individual letter literals (I, M, P, O, S, T, E, R) in the animated loader are an animated spelling effect. They will be replaced with a single `loader.imposter_word` key whose translated value is used character-by-character.*

**Total: ~100 keys.**

### 4.2 Pluralization

These keys require `.stringsdict` for proper plural rules across all locales:
- `voting.select_count` (select N player/players)  
- `result.subtitle_all_caught_format` (all N imposters caught)

All other `%lld` keys have fixed phrasing that doesn't change with count.

---

## 5. Word Pack Localization Strategy

### 5.1 The 8 localized packs

Each pack is fully rewritten per locale with ~65 culturally adapted words + parallel imposter hints.

| Pack | Cultural adaptation examples |
|---|---|
| **Party Time** | LATAM: Quinceañera, Mariachi; JP: Hanami, Matsuri; AR: Eid party elements; DE: Oktoberfest |
| **Food** | JP/KO: ramen, kimchi, takoyaki; AR: halal adaptations, mansaf, shawarma; MX: tacos, tamales, atole |
| **Family** | Replace Thanksgiving/Prom with: MX → Día de Muertos; FR → La Toussaint; KO → Chuseok; JP → Obon |
| **Movies** | Replace Oscars with: FR → César; IT → David di Donatello; DE → Lola; JP → Japanese Academy |
| **Music** | Replace Grammys with: FR → Victoires de la Musique; DE → ECHO; JP → Japan Record Award; KO → Melon Music Awards |
| **Places** | Replace Walmart/Yellowstone with locale equivalents; Universal landmarks kept (airport, museum, hospital) |
| **Sports** | Replace NFL/NBA with: ES → La Liga, Copa del Rey; DE → Bundesliga; JP → J-League, sumo; BR → Futebol; AR → cricket |
| **Spicy** | Universal romantic concepts retained; culturally inappropriate items swapped per locale |

### 5.2 JSON format — same schema as English

```json
{
  "category": "Festa",
  "icon": "party.popper",
  "description": "Caos total e risadas altas...",
  "isPremium": false,
  "words": ["Balão", "DJ", "Bolo", ...],
  "imposterHints": ["Alto ar", "Controle o ritmo", ...]
}
```

**`imposterHints` must be parallel to `words`** — same index, same count. The `GameEngine.hint(for:in:)` method uses array index matching.

### 5.3 The 8 English-only packs

celebrities, hobbies, school, shopping, tech, superpowers, travel, work_life — these stay in `en/` only. When a user's device is set to French, `CategoryLoader` will try `fr/celebrities.json` → not found → falls back to `en/celebrities.json`. The category is displayed in English for those packs, which is acceptable for Tier 1 launch.

Category `name` and `description` fields in English-only packs will be displayed as-is. The category name shown in the UI comes from `category.name` (populated from JSON), not from a Localizable.strings key. For the 8 localized packs the name is localized within the JSON itself.

---

## 6. RTL Support (Arabic)

- SwiftUI handles layout mirroring automatically for `ar` locale.
- No manual `layoutDirection` changes needed in views.
- Arabic numerals should be used in translated strings where numbers appear as text.
- Format strings (`%lld`, `%@`) are handled by the system's string formatting, which respects locale.

---

## 7. Implementation Phases

### Phase 1 — Infrastructure (no visible changes)
1. Move `Resources/WordPacks/*.json` → `Resources/WordPacks/en/*.json` (file system + Xcode project)
2. Update `CategoryLoader` to use locale-folder lookup with 3-tier fallback
3. Create all 25 `.lproj` directories
4. Add localizations to Xcode project settings

### Phase 2 — UI String Extraction
1. Create `en.lproj/Localizable.strings` with all ~100 keys
2. Update all 11 Views: replace string literals with `Text(LocalizedStringKey("key"))` or `NSLocalizedString()`
3. Create `.stringsdict` for the 2 plural keys
4. Verify English app still works identically

### Phase 3 — UI String Translation
1. Generate all 24 locale-specific `Localizable.strings` files
2. Generate corresponding `.stringsdict` plural rules for each locale (plural categories vary: Arabic has 6 forms, Russian-family languages have 3+, CJK languages have 1)
3. Special handling for `loader.imposter_word` in each locale (the animated word)
4. Verify RTL layout for Arabic

### Phase 4 — Word Pack Translation (8 packs × 24 locales)
1. Generate culturally-adapted word lists + imposter hints per locale
2. Validate: `words.count == imposterHints.count` for every file
3. Validate: JSON is valid and matches `WordPack` Codable schema
4. Add all JSON files to Xcode project (Copy Bundle Resources)

### Phase 5 — Integration Testing
1. Test locale switching on simulator for each language family
2. Verify CategoryLoader fallback for English-only packs
3. Verify hint mode works (imposterHints parallel alignment)
4. Verify RTL rendering (Arabic)
5. Verify pluralization for voting screen (1 player / 2 players)
6. Verify animated loader word works for CJK scripts

---

## 8. Files Changed / Created

| Change | Count |
|---|---|
| Existing JSON files moved to `en/` subfolder | 16 |
| New locale-specific word pack JSONs (8 packs × 24 locales) | 192 |
| New `Localizable.strings` files (25 locales) | 25 |
| New `.stringsdict` files (25 locales, 2 plural keys each) | 25 |
| Swift files modified (Views + CategoryLoader) | 13 |
| Xcode project file updated | 1 |

---

## 9. Out of Scope

- In-app language picker (currently shows "Coming soon" — keep as-is)
- RU-RU locale
- English-only 8 packs (celebrities, hobbies, school, shopping, tech, superpowers, travel, work_life) — English fallback only for Tier 1
- App Store metadata / screenshots localization
- Push notification localization
