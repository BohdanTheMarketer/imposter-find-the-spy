# Warehouse functions (Firebase Functions v2, us-central1)

| Функція | Хто викликає | Куди пише |
|---|---|---|
| `ingest` `POST /app/install` | застосунок, `WarehouseUploader` | `raw.app_installs` |
| `ingest` `POST /app/attribution` | застосунок, після AdServices | `raw.app_attribution` |
| `ingest` `POST /app/txmap` | застосунок, `Transaction.currentEntitlements` | `raw.app_transactions_map` |
| `appstoreNotifications` | Adapty («URL for forwarding raw Apple events») | `raw.appstore_notifications` |
| `refreshWarehouse` | Cloud Scheduler, щодня 06:00 Europe/Kiev | останні 7 днів (дні UTC): `raw.apple_ads_keyword_daily`, `raw.asc_subscriber_daily`, `raw.asc_sales_daily`, `ref.fx_daily` (секрети `APPLE_ADS_PRIVATE_KEY`, `ASC_API_KEY`) |
| `revenueForecast` | Cloud Scheduler, щодня 09:00 Europe/Kiev | Telegram (читає `mart.renewals_due`) |

Секрети `revenueForecast` (Secret Manager): `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `APPLE_ADS_PRIVATE_KEY` (spend за вчора; `--data-file ~/.secrets/imposter/apple-ads-private.pem`) —
`npx firebase-tools functions:secrets:set TELEGRAM_BOT_TOKEN --project imposter-who-s-the-spy`.
Ручний запуск: `gcloud scheduler jobs run firebase-schedule-revenueForecast-us-central1 --location us-central1`.

ASSN перевіряються підписом Apple (`certs/AppleRootCA-G3.cer`, SHA-256 `63:34:3A:BF:…:91:79`), Sandbox теж пишеться — фільтр у `mart.notifications`.

## Перед першим деплоєм
1. GCP Free Trial + Firebase Blaze на проєкті `imposter-who-s-the-spy`, budget alert $5.
2. Зняти sandbox expiration: `bq update --default_table_expiration 0 raw` (і `ref`, `mart`) + `bq update --expiration 0 raw.<table>` для кожної таблиці.
3. Service account функцій (`<project-number>-compute@developer.gserviceaccount.com`) — ролі `BigQuery Data Editor` на датасет `raw` і `BigQuery Job User`.

## Деплой
```
cd analytics/functions && npm install
npm run deploy          # = tsc + firebase deploy --only functions:warehouse
```
URL: `https://us-central1-imposter-who-s-the-spy.cloudfunctions.net/ingest` (зашитий у `WarehouseUploader.swift`)
і `…/appstoreNotifications` (вставити в Adapty).

## Перевірка
```
curl -i -X POST https://us-central1-imposter-who-s-the-spy.cloudfunctions.net/ingest/app/install \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"00000000-0000-4000-8000-000000000000","installed_at":"2026-10-15T00:00:00Z"}'
# → 204, рядок у raw.app_installs (тестовий id потім відфільтрувати/видалити)
```
ASC → App → App Store Server Notifications → «Request a Test Notification» → рядок `TEST` у `raw.appstore_notifications`.
