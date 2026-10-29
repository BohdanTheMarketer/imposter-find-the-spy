-- Imposter: сховище для окупності (keyword × ГЕО × місяць інсталу).
-- Запуск: BigQuery Console → новий запит → вставити весь файл → Run.
-- Або: bq query --use_legacy_sql=false < analytics/bigquery/schema.sql
-- Усі датасети в одній локації з Firebase export (тут US), інакше join між ними не працює.

-- ─────────────────────────────────────────────────────────────
-- 1. RAW: сирі дані як прийшли. Тільки дописуємо, нічого не змінюємо.
-- ─────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS raw OPTIONS (location = 'US');

-- Застосунок шле при першому запуску. user_id = UUID, той самий, що appAccountToken у покупках.
CREATE TABLE IF NOT EXISTS raw.app_installs (
  user_id        STRING NOT NULL,
  installed_at   TIMESTAMP NOT NULL,
  storefront     STRING,      -- Storefront.current.countryCode, alpha-3 (GBR)
  locale         STRING,      -- Locale.current.identifier (en_US)
  idfv           STRING,      -- identifierForVendor: зшивка з реінсталом, якщо Keychain очищено
  app_version    STRING,
  received_at    TIMESTAMP NOT NULL
)
PARTITION BY DATE(received_at);

-- Старі підписники купили до білда з appAccountToken: у їхніх нотифікаціях токена немає.
-- Застосунок при запуску шле originalTransactionId з Transaction.currentEntitlements.
CREATE TABLE IF NOT EXISTS raw.app_transactions_map (
  user_id                  STRING NOT NULL,
  original_transaction_id  STRING NOT NULL,
  received_at              TIMESTAMP NOT NULL
)
PARTITION BY DATE(received_at)
CLUSTER BY original_transaction_id;

-- Застосунок шле після відповіді AdServices (один раз на інстал).
CREATE TABLE IF NOT EXISTS raw.app_attribution (
  user_id            STRING NOT NULL,
  received_at        TIMESTAMP NOT NULL,
  attribution        BOOL,        -- false = органіка
  org_id             INT64,
  campaign_id        INT64,
  ad_group_id        INT64,
  keyword_id         INT64,
  ad_id              INT64,
  country_or_region  STRING,      -- alpha-2 (GB)
  click_date         TIMESTAMP,
  conversion_type    STRING,      -- Download / Redownload
  claim_type         STRING,
  supply_placement   STRING,
  raw                JSON
)
PARTITION BY DATE(received_at);

-- App Store Server Notifications v2, розкодовані Cloud Function (payload + signedTransactionInfo).
CREATE TABLE IF NOT EXISTS raw.appstore_notifications (
  notification_uuid        STRING NOT NULL,
  received_at              TIMESTAMP NOT NULL,
  signed_date              TIMESTAMP,
  notification_type        STRING,   -- SUBSCRIBED, DID_RENEW, REFUND, EXPIRED, DID_CHANGE_RENEWAL_STATUS…
  subtype                  STRING,   -- INITIAL_BUY, RESUBSCRIBE, AUTO_RENEW_DISABLED…
  environment              STRING,   -- Production / Sandbox
  app_account_token        STRING,   -- = user_id
  original_transaction_id  STRING,
  transaction_id           STRING,
  product_id               STRING,
  transaction_reason       STRING,   -- PURCHASE / RENEWAL
  offer_type               INT64,    -- 1 intro (trial), 2 promo, 3 offer code
  offer_discount_type      STRING,   -- FREE_TRIAL / PAY_AS_YOU_GO / PAY_UP_FRONT
  purchase_date            TIMESTAMP,
  original_purchase_date   TIMESTAMP,
  expires_date             TIMESTAMP,
  revocation_date          TIMESTAMP,
  price_milli              INT64,    -- ціна покупця × 1000, у валюті currency
  currency                 STRING,
  storefront               STRING,   -- alpha-3
  -- signedRenewalInfo
  auto_renew_status        INT64,    -- 1 увімкнено, 0 вимкнено (відмова від trial / підписки)
  expiration_intent        INT64,    -- 1 сам скасував, 2 billing error, 3 не погодився з ціною, 4 недоступний продукт
  is_in_billing_retry      BOOL,
  grace_period_expires_date TIMESTAMP,
  payload                  JSON
)
PARTITION BY DATE(received_at)
CLUSTER BY original_transaction_id;

-- App Store Connect → Sales Reports → SUBSCRIBER (DAILY). Джерело правди по грошах і країнах,
-- є з дня запуску, але без user_id: для звірки й історії, не для keyword.
CREATE TABLE IF NOT EXISTS raw.asc_subscriber_daily (
  event_date            DATE NOT NULL,
  subscriber_id         STRING,
  subscription_name     STRING,
  subscription_apple_id STRING,
  standard_duration     STRING,
  offer_type            STRING,
  offer_duration        STRING,
  customer_price        NUMERIC,
  customer_currency     STRING,
  developer_proceeds    NUMERIC,   -- net: без податку і комісії Apple
  proceeds_currency     STRING,
  proceeds_reason       STRING,    -- Rate After One Year → комісія 15%
  device                STRING,
  country               STRING,    -- alpha-2
  refund                STRING,    -- Yes / порожньо
  purchase_date         DATE,
  units                 INT64,
  loaded_at             TIMESTAMP NOT NULL
)
-- Без партицій: таблиця крихітна, а історія старша за рік — партиції за старими датами
-- в sandbox (expiration 60 днів від дати партиції) видалялися б одразу при заливці.
CLUSTER BY event_date, country;

-- App Store Connect → Sales Reports → SALES SUMMARY (DAILY). Звідси installs: product_type 1F —
-- first-time download (всі джерела, paid + organic), 3F — redownload, 7F — update; IAY — підписки.
CREATE TABLE IF NOT EXISTS raw.asc_sales_daily (
  event_date          DATE NOT NULL,
  product_type        STRING,     -- 1F / 3F / 7F / IAY …
  sku                 STRING,
  title               STRING,
  apple_identifier    STRING,
  parent_identifier   STRING,
  version             STRING,
  country             STRING,     -- alpha-2
  device              STRING,
  units               INT64,
  customer_price      NUMERIC,
  customer_currency   STRING,
  developer_proceeds  NUMERIC,
  proceeds_currency   STRING,
  promo_code          STRING,
  subscription        STRING,     -- New / Renewal
  period              STRING,
  order_type          STRING,     -- Free Trial Intro Offer …
  loaded_at           TIMESTAMP NOT NULL
)
-- Без партицій з тієї ж причини, що й asc_subscriber_daily.
CLUSTER BY event_date, country;

-- Apple Ads Campaign Management API → reports (keyword level, groupBy countryOrRegion, granularity DAILY).
CREATE TABLE IF NOT EXISTS raw.apple_ads_keyword_daily (
  date               DATE NOT NULL,
  org_id             INT64,
  campaign_id        INT64,
  campaign_name      STRING,
  ad_group_id        INT64,
  ad_group_name      STRING,
  keyword_id         INT64,
  keyword            STRING,
  match_type         STRING,
  country_or_region  STRING,       -- alpha-2
  impressions        INT64,
  taps               INT64,
  tap_installs       INT64,
  view_installs      INT64,
  spend              NUMERIC,      -- у валюті org
  currency           STRING,
  loaded_at          TIMESTAMP NOT NULL
)
-- Без партицій з тієї ж причини, що й asc_subscriber_daily (бекфіл історії spend).
CLUSTER BY date, country_or_region, keyword_id;

-- Adapty Analytics API (loaders/adapty_metrics_fetch.py): агрегати по днях у розрізі ASA-атрибуції Adapty.
-- Без user_id; дата — дата події (trial / підписка / платіж), не інсталу. segment NULL = без атрибуції.
-- segmentation: attribution_source / attribution_campaign / attribution_adgroup / attribution_creative (= keyword_id).
CREATE TABLE IF NOT EXISTS raw.adapty_metrics_daily (
  date          DATE NOT NULL,
  chart_id      STRING NOT NULL,   -- trials_new / subscriptions_new / revenue
  metric        STRING NOT NULL,   -- common (кількість) / revenue (gross) / proceeds / net_revenue
  segmentation  STRING NOT NULL,
  segment       STRING,
  value         NUMERIC,
  loaded_at     TIMESTAMP NOT NULL
)
CLUSTER BY date, segmentation;

-- Ранковий прогноз бота (functions revenueForecast): наступного дня порівнюємо з фактом і пояснюємо різницю.
-- pending — оплати, яких на момент прогнозу ще чекали, з шансом, за яким їх порахували. Перезапуск дня дає
-- ще один рядок — беремо останній за created_at.
CREATE TABLE IF NOT EXISTS raw.forecast_daily (
  date          DATE NOT NULL,     -- UTC-день прогнозу
  forecast_usd  FLOAT64 NOT NULL,
  already_usd   FLOAT64 NOT NULL,  -- вже списано на момент прогнозу
  pending       ARRAY<STRUCT<original_transaction_id STRING, due_at TIMESTAMP, kind STRING, country STRING,
                             net_usd FLOAT64, chance FLOAT64>>,
  created_at    TIMESTAMP NOT NULL
);

-- ─────────────────────────────────────────────────────────────
-- 2. REF: довідники, заповнюються вручну або раз на день.
-- ─────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS ref OPTIONS (location = 'US');

CREATE TABLE IF NOT EXISTS ref.fx_daily (
  date          DATE NOT NULL,
  currency      STRING NOT NULL,
  usd_per_unit  NUMERIC NOT NULL
);

-- Податок на storefront: щоб з ціни покупця отримати net для кожного платежу.
-- Дані: analytics/bigquery/ref_storefront.csv →
--   bq load --replace --source_format=CSV --skip_leading_rows=1 ref.storefront analytics/bigquery/ref_storefront.csv
-- Storefront без рядка тут рахується як ціна без податку (net завищений) — дописувати нові країни.
CREATE TABLE IF NOT EXISTS ref.storefront (
  storefront           STRING NOT NULL,  -- alpha-3 (GBR)
  country              STRING NOT NULL,  -- alpha-2 (GB)
  vat_rate             NUMERIC,          -- 0.20
  price_includes_tax   BOOL              -- true для ЄС/UK/UA, false для US/CA
);

-- ─────────────────────────────────────────────────────────────
-- 3. MART: views, які читає дашборд. Логіка тільки тут.
-- ─────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS mart OPTIONS (location = 'US');

-- Один рядок на користувача: коли поставив, звідки прийшов.
CREATE OR REPLACE VIEW mart.users AS
SELECT
  LOWER(i.user_id) AS user_id,   -- Swift UUID().uuidString — upper, Apple повертає токен у lower
  i.installed_at,
  DATE_TRUNC(DATE(i.installed_at), MONTH)               AS install_month,
  -- 0 / '??' замість NULL: інакше органіка випадає з join у cohort_payback
  COALESCE(a.country_or_region, s.country, '??')        AS country,
  IFNULL(a.attribution, FALSE)                          AS is_apple_ads,
  IFNULL(a.campaign_id, 0)                              AS campaign_id,
  IFNULL(a.ad_group_id, 0)                              AS ad_group_id,
  IFNULL(a.keyword_id, 0)                               AS keyword_id
FROM (
  SELECT * FROM raw.app_installs
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY installed_at) = 1
) i
LEFT JOIN (
  SELECT * FROM raw.app_attribution
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY received_at) = 1
) a USING (user_id)
LEFT JOIN ref.storefront s ON s.storefront = i.storefront;

-- Production-нотифікації без дублів (Apple ретраїть) із зшитим user_id:
-- appAccountToken з покупки, або — для старих підписників — мапінг originalTransactionId → user_id.
CREATE OR REPLACE VIEW mart.notifications AS
SELECT
  LOWER(COALESCE(n.app_account_token, m.user_id)) AS user_id,
  n.* EXCEPT (app_account_token, payload)
FROM (
  SELECT * FROM raw.appstore_notifications
  WHERE environment = 'Production'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY notification_uuid ORDER BY received_at) = 1
) n
LEFT JOIN (
  SELECT original_transaction_id, user_id FROM raw.app_transactions_map
  QUALIFY ROW_NUMBER() OVER (PARTITION BY original_transaction_id ORDER BY received_at) = 1
) m ON m.original_transaction_id = n.original_transaction_id;

-- Один рядок на гроші: платіж (+) або refund (−), у USD gross / tax / net.
CREATE OR REPLACE VIEW mart.payments AS
WITH tx AS (
  SELECT
    user_id,
    original_transaction_id,
    transaction_id,
    product_id,
    storefront,
    currency,
    price_milli / 1000 AS price_local,
    IF(notification_type = 'REFUND', -1, 1) AS sign,
    IF(notification_type = 'REFUND', DATE(revocation_date), DATE(purchase_date)) AS pay_date,
    CASE
      WHEN notification_type = 'REFUND' THEN 'refund'
      WHEN transaction_reason = 'RENEWAL' AND offer_type IS NULL THEN 'renewal'
      ELSE 'first_payment'
    END AS kind
  FROM mart.notifications
  WHERE notification_type IN ('SUBSCRIBED', 'DID_RENEW', 'REFUND')
    AND price_milli > 0
  QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id, notification_type ORDER BY received_at) = 1
),
priced AS (
  SELECT tx.*, s.country AS store_country,
    -- USD не потребує курсу; решта — з ref.fx_daily
    IF(tx.currency = 'USD', 1, fx.usd_per_unit) AS usd_rate,
    IF(s.price_includes_tax, tx.price_local / (1 + s.vat_rate), tx.price_local) AS ex_tax_local
  FROM tx
  LEFT JOIN ref.storefront s ON s.storefront = tx.storefront
  LEFT JOIN ref.fx_daily fx ON fx.date = tx.pay_date AND fx.currency = tx.currency
)
SELECT
  user_id, original_transaction_id, transaction_id, product_id, kind, pay_date, store_country,
  sign * price_local * usd_rate                   AS gross_usd,
  sign * (price_local - ex_tax_local) * usd_rate  AS tax_usd,
  -- Small Business Program: 15%. Якщо дохід за рік > $1M — змінити на 0.70.
  sign * ex_tax_local * 0.85 * usd_rate           AS net_usd
FROM priced;

-- Lifecycle підписки: одна подія на нотифікацію, нормалізована назва.
CREATE OR REPLACE VIEW mart.subscription_events AS
WITH n AS (
  SELECT *,
    IF(notification_type IN ('SUBSCRIBED', 'DID_RENEW'),
       LAG(offer_discount_type) OVER (
         PARTITION BY original_transaction_id, notification_type IN ('SUBSCRIBED', 'DID_RENEW')
         ORDER BY purchase_date),
       NULL) AS prev_offer_discount_type
  FROM mart.notifications
)
SELECT
  user_id,
  signed_date AS event_at,
  CASE
    WHEN notification_type = 'SUBSCRIBED' AND offer_discount_type = 'FREE_TRIAL' THEN 'trial_started'
    WHEN notification_type = 'SUBSCRIBED' AND subtype = 'RESUBSCRIBE'             THEN 'resubscribe'
    WHEN notification_type = 'SUBSCRIBED'                                         THEN 'subscribed'
    WHEN notification_type = 'DID_RENEW' AND subtype = 'BILLING_RECOVERY'         THEN 'billing_recovered'
    WHEN notification_type = 'DID_RENEW' AND prev_offer_discount_type = 'FREE_TRIAL' THEN 'trial_converted'
    WHEN notification_type = 'DID_RENEW'                                          THEN 'renewal'
    WHEN notification_type = 'DID_CHANGE_RENEWAL_STATUS' AND subtype = 'AUTO_RENEW_DISABLED'
         AND offer_discount_type = 'FREE_TRIAL' AND expires_date > signed_date    THEN 'trial_cancelled'
    WHEN notification_type = 'DID_CHANGE_RENEWAL_STATUS' AND subtype = 'AUTO_RENEW_DISABLED' THEN 'auto_renew_off'
    WHEN notification_type = 'DID_CHANGE_RENEWAL_STATUS' AND subtype = 'AUTO_RENEW_ENABLED'  THEN 'auto_renew_on'
    WHEN notification_type = 'DID_FAIL_TO_RENEW'                                  THEN 'billing_issue'
    WHEN notification_type = 'GRACE_PERIOD_EXPIRED'                               THEN 'grace_expired'
    WHEN notification_type = 'EXPIRED'                                            THEN 'expired'
    WHEN notification_type = 'REFUND'                                             THEN 'refund'
    WHEN notification_type = 'REFUND_REVERSED'                                    THEN 'refund_reversed'
    WHEN notification_type = 'REVOKE'                                             THEN 'revoked'
    ELSE LOWER(notification_type)
  END AS event,
  notification_type, subtype,
  original_transaction_id, transaction_id, product_id, storefront,
  offer_discount_type, purchase_date, original_purchase_date, expires_date,
  auto_renew_status, expiration_intent, is_in_billing_retry, grace_period_expires_date
FROM n;

-- Одна підписка (ланцюжок originalTransactionId): trial → конверсія → renewals → статус і net.
CREATE OR REPLACE VIEW mart.subscriptions AS
WITH e AS (SELECT * FROM mart.subscription_events),
agg AS (
  SELECT
    original_transaction_id,
    MAX(user_id)                                      AS user_id,
    MIN(original_purchase_date)                       AS started_at,
    MIN(IF(event = 'trial_started',   event_at, NULL)) AS trial_started_at,
    MIN(IF(event = 'trial_cancelled', event_at, NULL)) AS trial_cancelled_at,
    MIN(IF(event = 'trial_converted', event_at, NULL)) AS trial_converted_at,
    COUNTIF(event = 'renewal')                        AS renewals,
    COUNTIF(event = 'billing_issue')                  AS billing_issues,
    COUNTIF(event = 'billing_recovered')              AS billing_recoveries,
    COUNTIF(event = 'refund')                         AS refunds
  FROM e
  GROUP BY 1
),
last AS (
  SELECT original_transaction_id, event AS last_event, event_at AS last_event_at,
         product_id, storefront, offer_discount_type, expires_date,
         auto_renew_status, expiration_intent, is_in_billing_retry
  FROM e
  QUALIFY ROW_NUMBER() OVER (PARTITION BY original_transaction_id ORDER BY event_at DESC) = 1
),
money AS (
  SELECT original_transaction_id, SUM(gross_usd) AS gross_usd, SUM(net_usd) AS net_usd
  FROM mart.payments
  GROUP BY 1
)
SELECT
  agg.*,
  last.* EXCEPT (original_transaction_id),
  CASE
    WHEN last.last_event IN ('refund', 'revoked')                        THEN 'refunded'
    WHEN last.is_in_billing_retry                                        THEN 'billing_retry'
    WHEN last.expires_date < CURRENT_TIMESTAMP()                         THEN 'expired'
    WHEN last.offer_discount_type = 'FREE_TRIAL'                         THEN 'trial'
    ELSE 'active'
  END                                   AS status,
  last.auto_renew_status = 1            AS will_renew,
  IFNULL(money.gross_usd, 0)            AS gross_usd,
  IFNULL(money.net_usd, 0)              AS net_usd
FROM agg
JOIN last USING (original_transaction_id)
LEFT JOIN money USING (original_transaction_id);

-- Один рядок на trial: день старту (UTC) і поточний статус — для графіка «тріали по днях старту».
-- not_cancelled = ще в тріалі з auto-renew, вже сконвертився або в billing retry.
-- Повні дані з 2026-10-25: раніше Adapty ще не форвардив нотифікації.
CREATE OR REPLACE VIEW mart.trials AS
WITH e AS (SELECT * FROM mart.subscription_events),
start AS (
  SELECT original_transaction_id, user_id, product_id, storefront,
         purchase_date AS trial_started_at, expires_date AS trial_ends_at
  FROM e
  WHERE event = 'trial_started'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY original_transaction_id ORDER BY purchase_date) = 1
),
agg AS (
  SELECT original_transaction_id,
    MAX(user_id)                                       AS user_id,
    MIN(IF(event = 'trial_cancelled', event_at, NULL)) AS trial_cancelled_at,
    MIN(IF(event = 'trial_converted', event_at, NULL)) AS trial_converted_at,
    COUNTIF(event = 'refund') > 0                      AS refunded
  FROM e GROUP BY 1
),
last AS (
  SELECT original_transaction_id, auto_renew_status, is_in_billing_retry
  FROM e
  QUALIFY ROW_NUMBER() OVER (PARTITION BY original_transaction_id ORDER BY event_at DESC) = 1
),
t AS (
  SELECT
    s.original_transaction_id,
    COALESCE(agg.user_id, s.user_id) AS user_id,
    s.product_id,
    DATE(s.trial_started_at)         AS trial_date,
    s.trial_started_at, s.trial_ends_at,
    agg.trial_cancelled_at, agg.trial_converted_at,
    COALESCE(st.country, s.storefront) AS country,
    CASE
      WHEN agg.refunded                         THEN 'refunded'
      WHEN agg.trial_converted_at IS NOT NULL   THEN 'converted'
      WHEN last.is_in_billing_retry             THEN 'billing_issue'
      WHEN last.auto_renew_status = 0           THEN 'cancelled'
      WHEN s.trial_ends_at > CURRENT_TIMESTAMP() THEN 'in_trial'
      ELSE 'expired'
    END AS status
  FROM start s
  JOIN agg USING (original_transaction_id)
  JOIN last USING (original_transaction_id)
  LEFT JOIN ref.storefront st ON st.storefront = s.storefront
)
SELECT t.*,
  t.status IN ('in_trial', 'converted', 'billing_issue') AS not_cancelled,
  u.is_apple_ads, u.campaign_id, u.keyword_id
FROM t
LEFT JOIN mart.users u USING (user_id);

-- Один рядок на платіжний період, що закінчується (trial або тиждень підписки): чи оплачено продовження
-- і скільки чекаємо net. Читає функція revenueForecast (щоденний прогноз у Telegram).
CREATE OR REPLACE VIEW mart.renewals_due AS
WITH renewal AS (
  -- renewalPrice є тільки в payload: скільки Apple спише наступного разу (валюта покупця × 1000).
  SELECT notification_uuid,
    SAFE_CAST(JSON_VALUE(payload, '$.renewal.renewalPrice') AS INT64) AS renewal_price_milli,
    JSON_VALUE(payload, '$.renewal.currency')                         AS renewal_currency
  FROM raw.appstore_notifications
  QUALIFY ROW_NUMBER() OVER (PARTITION BY notification_uuid ORDER BY received_at) = 1
),
n AS (
  SELECT n.*, r.renewal_price_milli, r.renewal_currency
  FROM mart.notifications n JOIN renewal r USING (notification_uuid)
),
-- Період = транзакція. З будь-якої нотифікації, не лише SUBSCRIBED/DID_RENEW: так видно й періоди
-- старих підписників, оплачені до старту форвардингу (2026-10-24).
periods AS (
  SELECT original_transaction_id, transaction_id,
    ANY_VALUE(user_id) AS user_id, ANY_VALUE(product_id) AS product_id,
    ANY_VALUE(storefront) AS storefront, ANY_VALUE(currency) AS currency,
    ANY_VALUE(price_milli) AS price_milli, ANY_VALUE(offer_discount_type) AS offer_discount_type,
    ANY_VALUE(transaction_reason) AS transaction_reason,
    ANY_VALUE(purchase_date) AS purchase_date, ANY_VALUE(expires_date) AS expires_date
  FROM n
  WHERE transaction_id IS NOT NULL AND expires_date IS NOT NULL AND notification_type != 'REFUND'
  GROUP BY 1, 2
),
latest AS (
  SELECT original_transaction_id, auto_renew_status, is_in_billing_retry,
    LAST_VALUE(renewal_price_milli IGNORE NULLS) OVER w AS renewal_price_milli,
    LAST_VALUE(renewal_currency IGNORE NULLS)    OVER w AS renewal_currency
  FROM n
  QUALIFY ROW_NUMBER() OVER (PARTITION BY original_transaction_id ORDER BY signed_date DESC) = 1
  WINDOW w AS (PARTITION BY original_transaction_id ORDER BY signed_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
),
-- Оплата за період: наступна транзакція ланцюжка. Вчасне продовження стартує рівно в expires_date.
paid AS (
  SELECT p.transaction_id,
    ARRAY_AGG(STRUCT(x.transaction_id, x.purchase_date, x.price_milli, x.currency)
              ORDER BY x.purchase_date LIMIT 1)[OFFSET(0)] AS nx
  FROM periods p
  JOIN periods x
    ON x.original_transaction_id = p.original_transaction_id
   AND x.purchase_date >= TIMESTAMP_SUB(p.expires_date, INTERVAL 1 MINUTE)
   AND x.transaction_id != p.transaction_id
  GROUP BY 1
),
fx AS (
  -- ref.fx_daily оновлюється вручну — беремо останній відомий курс.
  SELECT currency, usd_per_unit FROM ref.fx_daily
  QUALIFY ROW_NUMBER() OVER (PARTITION BY currency ORDER BY date DESC) = 1
),
d AS (
  SELECT
    p.original_transaction_id, p.transaction_id, p.user_id, p.product_id, p.storefront,
    IF(p.offer_discount_type = 'FREE_TRIAL', 'trial', 'renewal') AS kind,
    p.expires_date AS due_at,
    CASE
      WHEN pd.nx.purchase_date <= TIMESTAMP_ADD(p.expires_date, INTERVAL 1 MINUTE) THEN 'paid'
      WHEN pd.nx.transaction_id IS NOT NULL      THEN 'paid_late'      -- billing recovery
      WHEN l.is_in_billing_retry                 THEN 'billing_retry'
      WHEN l.auto_renew_status = 0               THEN 'cancelled'
      WHEN p.expires_date > CURRENT_TIMESTAMP()  THEN 'pending'
      ELSE 'lapsed'
    END AS state,
    pd.nx.purchase_date      AS paid_at,
    pd.nx.price_milli / 1000 AS paid_local,
    pd.nx.currency           AS paid_currency,
    COALESCE(l.renewal_price_milli, NULLIF(p.price_milli, 0)) / 1000 AS expected_local,
    COALESCE(l.renewal_currency, p.currency)                        AS expected_currency
  FROM periods p
  JOIN latest l USING (original_transaction_id)
  LEFT JOIN paid pd USING (transaction_id)
  UNION ALL
  -- Продовження, чий попередній період ми не бачили (оплачений до 2026-10-24): оплата сама по собі.
  SELECT
    x.original_transaction_id, CONCAT('prev:', x.transaction_id), x.user_id, x.product_id, x.storefront,
    'renewal', x.purchase_date, 'paid',
    x.purchase_date, x.price_milli / 1000, x.currency,
    x.price_milli / 1000, x.currency
  FROM periods x
  WHERE x.transaction_reason = 'RENEWAL'
    AND x.transaction_id NOT IN (SELECT nx.transaction_id FROM paid)
)
SELECT d.*,
  -- net як у mart.payments: без VAT, мінус 15% Apple, у USD
  IF(s.price_includes_tax, d.paid_local / (1 + s.vat_rate), d.paid_local) * 0.85
    * IF(d.paid_currency = 'USD', 1, fp.usd_per_unit)                         AS paid_net_usd,
  IF(s.price_includes_tax, d.expected_local / (1 + s.vat_rate), d.expected_local) * 0.85
    * IF(d.expected_currency = 'USD', 1, fe.usd_per_unit)                     AS expected_net_usd
FROM d
LEFT JOIN ref.storefront s ON s.storefront = d.storefront
LEFT JOIN fx fp ON fp.currency = d.paid_currency
LEFT JOIN fx fe ON fe.currency = d.expected_currency;

-- Spend по keyword × країна × день у USD.
CREATE OR REPLACE VIEW mart.spend AS
SELECT
  a.date, a.campaign_id, a.campaign_name, a.ad_group_id, a.keyword_id, a.keyword,
  a.country_or_region AS country,
  a.taps, a.tap_installs + a.view_installs AS installs,
  a.spend * IF(a.currency = 'USD', 1, fx.usd_per_unit) AS spend_usd
FROM raw.apple_ads_keyword_daily a
LEFT JOIN ref.fx_daily fx ON fx.date = a.date AND fx.currency = a.currency;

-- Головна вітрина: keyword × країна × місяць інсталу → інстали, платники, net по M0..M6, spend, ROAS.
CREATE OR REPLACE VIEW mart.cohort_payback AS
WITH rev AS (
  SELECT
    u.install_month, u.country, u.campaign_id, u.keyword_id,
    DATE_DIFF(DATE_TRUNC(p.pay_date, MONTH), u.install_month, MONTH) AS month_n,
    p.user_id, p.net_usd
  FROM mart.payments p
  JOIN mart.users u USING (user_id)
),
coh AS (
  SELECT install_month, country, campaign_id, keyword_id, COUNT(*) AS installs
  FROM mart.users
  GROUP BY 1, 2, 3, 4
),
sp AS (
  SELECT DATE_TRUNC(date, MONTH) AS install_month, country, campaign_id, keyword_id,
         SUM(spend_usd) AS spend_usd
  FROM mart.spend
  GROUP BY 1, 2, 3, 4
)
SELECT
  c.install_month, c.country, c.campaign_id, c.keyword_id,
  c.installs,
  COUNT(DISTINCT r.user_id)                                AS payers,
  SUM(IF(r.month_n <= 0, r.net_usd, 0))                    AS net_m0,
  SUM(IF(r.month_n <= 1, r.net_usd, 0))                    AS net_m1,
  SUM(IF(r.month_n <= 2, r.net_usd, 0))                    AS net_m2,
  SUM(IF(r.month_n <= 3, r.net_usd, 0))                    AS net_m3,
  SUM(IF(r.month_n <= 6, r.net_usd, 0))                    AS net_m6,
  IFNULL(SUM(r.net_usd), 0)                                AS net_total,
  ANY_VALUE(s.spend_usd)                                   AS spend_usd,
  SAFE_DIVIDE(IFNULL(SUM(r.net_usd), 0), ANY_VALUE(s.spend_usd)) AS roas
FROM coh c
LEFT JOIN rev r USING (install_month, country, campaign_id, keyword_id)
LEFT JOIN sp  s USING (install_month, country, campaign_id, keyword_id)
GROUP BY 1, 2, 3, 4, 5;

-- Installs по днях і країнах з ASC (усі джерела) + Apple Ads installs поруч — для CR to trial і частки paid.
-- Apple Ads рахує й redownloads та view-through, тому paid_share трохи завищений.
CREATE OR REPLACE VIEW mart.installs_daily AS
WITH asc_i AS (
  SELECT event_date AS date, country,
    SUM(IF(product_type = '1F', units, 0)) AS first_downloads,
    SUM(IF(product_type = '3F', units, 0)) AS redownloads
  FROM raw.asc_sales_daily
  WHERE product_type IN ('1F', '3F')
  GROUP BY 1, 2
),
ads AS (
  SELECT date, country, SUM(installs) AS apple_ads_installs, SUM(spend_usd) AS spend_usd
  FROM mart.spend
  GROUP BY 1, 2
)
SELECT
  date, country,
  IFNULL(first_downloads, 0)    AS first_downloads,
  IFNULL(redownloads, 0)        AS redownloads,
  IFNULL(apple_ads_installs, 0) AS apple_ads_installs,
  IFNULL(spend_usd, 0)          AS spend_usd
FROM asc_i FULL OUTER JOIN ads USING (date, country);

-- Історія грошей з App Store Connect (з дня запуску, без user_id): ГЕО × місяць і звірка з mart.payments.
-- У refund-рядках Apple пише customer_price від'ємним, а developer_proceeds — додатним, тому знак — з refund.
CREATE OR REPLACE VIEW mart.asc_revenue AS
SELECT
  s.event_date,
  DATE_TRUNC(s.event_date, MONTH) AS month,
  s.country,
  s.subscription_name,
  s.subscriber_id,
  CASE
    WHEN s.refund = 'Yes'                                   THEN 'refund'
    WHEN s.offer_type = 'Free Trial' AND s.customer_price = 0 THEN 'trial_started'
    WHEN s.customer_price > 0                               THEN 'payment'
    ELSE 'other'
  END AS kind,
  s.units,
  IF(s.refund = 'Yes', -1, 1) * ABS(s.customer_price)
    * IF(s.customer_currency = 'USD', 1, fxc.usd_per_unit)   AS gross_usd,
  IF(s.refund = 'Yes', -1, 1) * ABS(s.developer_proceeds)
    * IF(s.proceeds_currency = 'USD', 1, fxp.usd_per_unit)   AS net_usd
FROM raw.asc_subscriber_daily s
LEFT JOIN ref.fx_daily fxc ON fxc.date = s.event_date AND fxc.currency = s.customer_currency
LEFT JOIN ref.fx_daily fxp ON fxp.date = s.event_date AND fxp.currency = s.proceeds_currency;
