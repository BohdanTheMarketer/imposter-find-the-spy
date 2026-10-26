# Warehouse functions (Firebase Functions v2, us-central1)

| Функція | Хто викликає | Куди пише |
|---|---|---|
| `ingest` `POST /app/install` | застосунок, `WarehouseUploader` | `raw.app_installs` |
| `ingest` `POST /app/attribution` | застосунок, після AdServices | `raw.app_attribution` |
| `ingest` `POST /app/txmap` | застосунок, `Transaction.currentEntitlements` | `raw.app_transactions_map` |
| `appstoreNotifications` | Adapty («URL for forwarding raw Apple events») | `raw.appstore_notifications` |
| `loadFxDaily` | Cloud Scheduler, 06:00 UTC | `ref.fx_daily` |
| `loadAppleAdsDaily` | Cloud Scheduler, 07:00 UTC | `raw.apple_ads_keyword_daily` (keyword + залишок `keyword_id = 0`) |
| `loadAscSalesDaily` | Cloud Scheduler, 17:00 UTC | `raw.asc_sales_daily` |
| `loadAscSubscriberDaily` | Cloud Scheduler, 17:15 UTC | `raw.asc_subscriber_daily` |

ASSN перевіряються підписом Apple (`certs/AppleRootCA-G3.cer`, SHA-256 `63:34:3A:BF:…:91:79`), Sandbox теж пишеться — фільтр у `mart.notifications`.

## Перед першим деплоєм
1. GCP Free Trial + Firebase Blaze на проєкті `imposter-who-s-the-spy`, budget alert $5.
2. Зняти sandbox expiration: `bq update --default_table_expiration 0 raw` (і `ref`, `mart`) + `bq update --expiration 0 raw.<table>` для кожної таблиці.
3. Service account функцій (`1089195579806-compute@developer.gserviceaccount.com`) — ролі `BigQuery Data Editor` на датасети `raw` **і `ref`** (fx) та `BigQuery Job User` на проєкт.
4. Секрети для лоадерів (Secret Manager; доступ функціям firebase видає сам при деплої):
   ```
   npx firebase-tools functions:secrets:set ASC_API_KEY --data-file ~/.secrets/imposter/AuthKey_69AVX6PM25.p8 --project imposter-who-s-the-spy
   npx firebase-tools functions:secrets:set APPLE_ADS_PRIVATE_KEY --data-file ~/.secrets/imposter/apple-ads-private.pem --project imposter-who-s-the-spy
   ```
   `ASC_API_KEY` — App Store Connect API key (Issuer `6d7538b8-…`, Key ID `69AVX6PM25`, роль Sales/Finance).
   `APPLE_ADS_PRIVATE_KEY` — приватний ключ API-користувача Apple Ads (client `SEARCHADS.9a079a92-…`, key id `49d9ffcc-…`).
   Ідентифікатори (не секрети) — константи в `src/loaders.ts`.

## Деплой
```
cd analytics/functions && npm install
npm run deploy          # = tsc + firebase deploy --only functions:warehouse
```
URL: `https://us-central1-imposter-who-s-the-spy.cloudfunctions.net/ingest` (зашитий у `WarehouseUploader.swift`)
і `…/appstoreNotifications` (вставити в Adapty).

## Щоденні лоадери (`src/loaders.ts`)
Порт `analytics/loaders/*.py`. Кожен запуск перечитує останні 7 днів (`LOOKBACK_DAYS` у `src/index.ts`) —
Apple переписує свіжі дні — і робить upsert по даті: рядки load job-ом у тимчасову `_stage_<table>_<ts>`
(expiration 1 год, видаляється одразу), далі одна транзакція `DELETE … WHERE date IN (…)` + `INSERT … SELECT`.
Помилка API кидає виняток до upsert — таблиця лишається як була, Cloud Scheduler повторює (retryCount 2),
а пропущений день доллється наступного дня, поки він у вікні 7 днів.

- ASC: видаляються лише дні, за які прийшов звіт; 404 (звіт ще не готовий) старі рядки не чіпає.
- Apple Ads: видаляється весь діапазон (день без рядків = нульовий spend). У лозі `apple ads fetched` —
  звірка keyword + залишок vs spend кампаній; розбіжність > $0.05 пишеться як warning.
- FX: дні, для яких API не віддав курси, пропускаються.

Ручний запуск у консолі: Cloud Scheduler → `firebase-schedule-loadAppleAdsDaily-us-central1` → Force run,
або `gcloud scheduler jobs run firebase-schedule-loadAppleAdsDaily-us-central1 --location us-central1`.
Логи: `npx firebase-tools functions:log --only loadAppleAdsDaily`.

### Бекфіл за довший період (локально, той самий код)
Потрібні `gcloud auth application-default login` і ключі в `~/.secrets/imposter/`
(або шляхи в `ASC_API_KEY_FILE` / `APPLE_ADS_PRIVATE_KEY_FILE`):
```
npm run build
node lib/backfill.js apple_ads 2026-10-13          # до вчора; upsert лише цих дат
node lib/backfill.js asc_sales 2026-10-20 2026-10-24
node lib/backfill.js asc_subscriber 2026-10-20
node lib/backfill.js fx 2026-10-01
```
Рядки Apple Ads за 13–25.10, які дозаливались з Adapty (UTC-дні), замінюються API-даними (ORTZ)
при першому ж запуску для останніх 7 днів; 13–17.10 — через `backfill.js apple_ads 2026-10-13`.

## Перевірка
```
curl -i -X POST https://us-central1-imposter-who-s-the-spy.cloudfunctions.net/ingest/app/install \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"00000000-0000-4000-8000-000000000000","installed_at":"2026-10-15T00:00:00Z"}'
# → 204, рядок у raw.app_installs (тестовий id потім відфільтрувати/видалити)
```
ASC → App → App Store Server Notifications → «Request a Test Notification» → рядок `TEST` у `raw.appstore_notifications`.
