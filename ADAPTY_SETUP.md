# Adapty integration — handoff

Migration from native StoreKit 2 to Adapty (Flow Builder). Adapty app: **Imposter: Find The Spy**
(`04e865e5-b9e1-41cd-b442-a1c3749515a6`).

## Done

- Adapty + AdaptyUI SDK (v4.1.x) added via `project.yml` / XcodeGen — do not add it again through
  Xcode's UI, edit `project.yml` instead and run `xcodegen generate`.
- `Adapty.activate()` + `Adapty.identify()` (using the Firebase Installation ID) wired in
  `ImposterGame/App/ImposterGameApp.swift`.
- Products created in Adapty: Weekly (`com.vertebro.imposter.weekly`), Yearly
  (`com.vertebro.imposter.yearly`), both under the `premium` access level.
- Flow "Premium Paywall" (`a131556c-ecd7-405d-8333-fce392fa80d1`) built in Flow Builder, published.
- 3 placements, all pointing at that flow: `onboarding`, `category_paywall`, `post_game`.
- `SubscriptionManager.swift` rewritten: `isPremium` now driven by the Adapty profile; the raw
  StoreKit transaction-analytics pipeline (payment counters, trial/renewal/refund detection,
  sandbox filtering, attribution) was kept as-is and still runs in parallel, read-only.
- All 3 paywall views (`OnboardingPaywallView`, `CategoryPaywallView`, `PostGamePaywallView`) now
  fetch+present the Flow via `AdaptyFlowView` instead of a hand-built SwiftUI paywall.
- `Adapty.setIntegrationIdentifier` wired for both Amplitude (`amplitudeDeviceId`) and
  Firebase/GA (`firebaseAppInstanceId`).
- `Adapty.logShowFlow` called on every paywall impression (needed for Adapty's own paywall
  analytics / A/B test attribution).

## Manual steps — completed by the user

1. ✅ Amplitude integration dashboard config
2. ✅ Firebase/GA integration dashboard config
3. ✅ Connect App Store to Adapty
4. ✅ App Store Server Notifications (v2)

## Review findings — all fixed

A five-way review of the migration found these; every one has since been fixed.

- **Entitlement lifecycle (the severe cluster).** The Combine subscription on
  `AdaptyService.$profile` both replayed `nil` synchronously on subscribe and re-read the property
  inside the sink (`@Published` publishes in `willSet`), so: the Keychain premium cache was
  overwritten with `false` on every cold launch before the SDK had even activated; every
  server-pushed profile was processed one step stale; and `entitlement_state_changed` fired a fake
  `inactive → active` on each launch. Fixed by passing the emitted profile through explicitly and
  dropping the `nil` replay. `reloadProfile()` also no longer publishes `nil` on a failed fetch,
  and `syncPremiumStatus` treats a `nil` profile as "not resolved yet", never "no subscription" —
  a subscriber opening the app offline keeps their access.
- **Paid-but-locked.** A `.success` whose profile did not yet carry the access level closed the
  paywall as a win. `handleFlowPurchaseFinished` now returns whether access is actually active,
  and the views close on that.
- **One-shot flags burned by a failed load.** `markPaywallShown`, `markPostGamePaywallShown`,
  `hasSeenCategoryPaywallThisSession`, `hasDeclinedOnboardingPaywall` and `paywall_viewed` all ran
  in `onAppear`, before the flow was known to load — so an offline user permanently lost the
  paywall they never saw. All of it moved into the successful-load branch.
- **`transaction.finish()`** removed from the retained StoreKit analytics listener: Adapty owns
  validation now and finishing first could lose a renewal it had not yet reported.
- **`project.yml` drift.** `xcodegen generate` had destroyed `ENABLE_USER_SCRIPT_SANDBOXING`,
  `CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED` and `STRING_CATALOG_GENERATE_SYMBOLS` (the same
  class of bug as the earlier `FirebaseFirestore` loss). All three are now declared in
  `project.yml`, and a repeat generate is verified idempotent.
- **Double-booked revenue.** Adapty's server-side Amplitude integration reports the same purchases,
  so the client-side `AmplitudeManager.logRevenue` call was removed (and the now-dead method with
  it). Adapty is the revenue source of truth — it also catches renewals and refunds that happen
  while the app is closed. The custom `subscription_transaction` event stays: it is invisible to
  Amplitude's revenue reports but carries `payment_number`, `trial_enabled` and `paywall_context`.
- **Four funnel events restored.** `paywall_plan_selected`, `paywall_continue_tapped`,
  `paywall_restore_tapped` and `paywall_link_tapped` fire again, wired from the Flow's
  `didSelectProduct` / `didStartPurchase` / `didStartRestore` / `.openURL` callbacks. Link type is
  recovered from the URL, since the Flow reports a URL rather than a semantic type.
- **`trial_eligibility` / `trial_enabled` corrected.** They were derived from
  `subscriptionOffer != nil`, which also matches promotional and win-back offers; they now require
  `offerType == .introductory`, so a win-back deal no longer reports as a trial.
- **`.custom` Flow actions** are no longer silently dropped — ids that read as dismissal
  (`close`, `skip`, `dismiss`, `cancel`, `later`, `not_now`) close the paywall. The nav bar is
  hidden on the pushed paywalls, so this is the difference between an exit and a trap if the
  dashboard flow ever uses a custom action for its close control.
- **Swift 6 concurrency.** `didLoadLatestProfile` is `nonisolated` and hops to `@MainActor`
  explicitly; the build now has no warnings.
- **Orphans removed:** 47 dead `paywall.*` / `category_paywall.*` / `legal.terms_short` keys per
  locale (×5), and the two unused hero images (~400 KB). Locale key parity preserved; the only
  remaining gap is 9 untranslated `survey.*` keys, which predates this work.
- **Repo hygiene:** `.agents/` and `skills-lock.json` are now gitignored.

## Still open

5. **Sandbox test purchase end-to-end** — not yet run. Before shipping, do a real sandbox
   purchase on device (sandbox tester account, direct Xcode run — not the simulator) through each
   of the 3 paywall placements and confirm: Flow renders with real prices, purchase completes,
   `profile.accessLevels["premium"].isActive` flips true in the Adapty dashboard, restore works
   after reinstall. See `https://adapty.io/docs/app-store-test`.

6. **Historical StoreKit subscribers** — existing users who already had `com.imposter.isPremium`
   true via the old Keychain flag will still read `true` from that cache at cold start, but the
   Adapty profile becomes the source of truth the moment `refreshSubscriptionStatus` runs (first
   launch after this update). Adapty establishes their access from Apple's own store transaction
   history automatically once they open a build with the new SDK — no manual backfill needed for
   store purchases. There is no access granted outside the App Store in this app (no backend
   grant path), so nothing further is needed here.
