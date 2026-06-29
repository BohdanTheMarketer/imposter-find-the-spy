# GA4: Subscription Funnel & Cohort Setup

Інструкція для налаштування Firebase / GA4 після deploy app-івентів `subscription_transaction`.

## Prerequisite

1. Firebase Console → Project Settings → Integrations → **App Store Connect** — переконайся, що лінк активний.
2. Зачекай 24–48 год після deploy, щоб custom parameters з'явились в GA4 (або зареєструй definitions заздалегідь).

---

## 1. Custom Definitions

Admin → Data display → **Custom definitions**

### Event-scoped dimensions

| Parameter name | Event parameter | Scope |
|----------------|-----------------|-------|
| Transaction type | `transaction_type` | Event |
| Offer type | `offer_type` | Event |
| Payment number | `payment_number` | Event |
| Paywall context | `paywall_context` | Event |
| Trial enabled | `trial_enabled` | Event |
| Trial eligibility | `trial_eligibility` | Event |
| Plan | `plan` | Event |
| Product ID | `product_id` | Event |
| Purchase result | `result` | Event |

### User-scoped dimensions

| Parameter name | User property | Scope |
|----------------|---------------|-------|
| Subscription status | `subscription_status` | User |
| Install week | `install_week` | User |
| Active plan | `active_plan` | User |
| Is premium | `is_premium` | User |

### Monetization event

Admin → Data display → **Events** → знайди `subscription_transaction` → toggle **Mark as conversion** (optional) + переконайся, що `value` і `currency` розпізнаються як revenue params.

Альтернатива: Admin → Data display → **Key events** → Create event → `subscription_transaction` where `transaction_type` != `trial_start`.

---

## 2. Funnel Exploration — Subscription Lifecycle

Explore → **Funnel exploration** → Create new

| Setting | Value |
|---------|-------|
| Technique | Funnel exploration |
| Open funnel | OFF (послідовність обов'язкова) |
| Date range | Last 28 days |

### Steps (trial path)

| Step | Event | Condition |
|------|-------|-----------|
| 1 | `first_open` | — |
| 2 | `onboarding_complete` | — |
| 3 | `paywall_viewed` | — |
| 4 | `paywall_continue_tapped` | `trial_enabled` = true |
| 5 | `subscription_transaction` | `transaction_type` = `trial_start` |
| 6 | `subscription_transaction` | `transaction_type` = `renewal`, `payment_number` = 1 |
| 7 | `subscription_transaction` | `transaction_type` = `renewal`, `payment_number` >= 2 |

> Step 6 = перша оплата після trial (StoreKit reason=renewal).  
> Для direct subscribe без trial: Step 4 `trial_enabled` = false → Step 6 `transaction_type` = `initial_purchase`.

### Breakdown dimensions

- `paywall_context` (onboarding vs category)
- `plan` (weekly vs yearly)
- First user source / medium (ASA vs organic)

### Окрема воронка — direct paid (без trial)

| Step | Event | Condition |
|------|-------|-----------|
| 1 | `paywall_viewed` | — |
| 2 | `paywall_continue_tapped` | `trial_enabled` = false |
| 3 | `subscription_transaction` | `transaction_type` = `initial_purchase` |

---

## 3. Cohort Exploration — Install Cohort → Paid

Explore → **Cohort exploration** → Create new

| Setting | Value |
|---------|-------|
| Cohort inclusion | `first_open` |
| Granularity | Weekly |
| Return criteria | `subscription_transaction` |
| Return criteria filter | `transaction_type` = `initial_purchase` OR (`transaction_type` = `renewal` AND `payment_number` = 1) |
| Metric | Event count per user |

Показує: когорта install week X → % users з першим платежем за D0/D3/D7/D14.

### Cohort — Product retention

| Setting | Value |
|---------|-------|
| Cohort inclusion | `first_open` |
| Return criteria | `game_start` |
| Metric | Retention |

### Cohort — Renewal (2nd payment)

| Setting | Value |
|---------|-------|
| Cohort inclusion | `first_open` |
| Return criteria | `subscription_transaction` |
| Return criteria filter | `payment_number` = 2 |
| Metric | Event count per user |

---

## 4. Free Form — Діагностика gap purchase_result vs revenue

Explore → **Free form**

Додай рядки (metrics = Event count + Total revenue):

| Event | Filter |
|-------|--------|
| `purchase_result` | `result` = `success_verified` |
| `subscription_transaction` | `transaction_type` = `trial_start` |
| `subscription_transaction` | `payment_number` = 1 |
| `subscription_transaction` | `payment_number` >= 2 |
| `app_store_subscription_convert` | — |
| `app_store_subscription_renew` | — |

Очікування:
- `purchase_result success_verified` ≈ `trial_start` + `initial_purchase` (не ≈ revenue)
- `payment_number = 1` ≈ `app_store_subscription_convert` + direct `initial_purchase` (з lag 24–72h для auto events)

---

## 5. Monetization Overview

Reports → **Monetization** → Overview

Після реєстрації monetization event:
- Revenue by `transaction_type`
- Breakdown by `install_week` user property

---

## Event Reference (app)

### `subscription_transaction`

| Parameter | Values |
|-----------|--------|
| `transaction_type` | `trial_start`, `initial_purchase`, `renewal`, `refund` |
| `offer_type` | `introductory`, `standard`, `promotional` |
| `payment_number` | 0 = trial/refund, 1 = first payment, 2+ = renewals |
| `value` | Price (0 for trial) |
| `currency` | ISO code |
| `trigger` | `purchase_success`, `transaction_update` |
| `paywall_context` | `onboarding`, `category` |
| `trial_enabled` | true/false |

### `purchase_started` / `purchase_result` (extended)

Додано: `trial_enabled`, `trial_eligibility` (`new`, `trial_used`, `active_subscriber`, `unknown`).

### User properties

| Property | Values |
|----------|--------|
| `subscription_status` | `free`, `trial`, `paid`, `expired` |
| `install_week` | `2026-W26` (ISO week, set once) |
