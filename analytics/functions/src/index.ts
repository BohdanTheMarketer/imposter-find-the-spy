// Прийом даних у BigQuery-сховище (схема — analytics/bigquery/schema.sql).
//   ingest                — застосунок: /app/install, /app/attribution, /app/txmap
//   appstoreNotifications — App Store Server Notifications v2, які пересилає Adapty
//                           («URL for forwarding raw Apple events»)
//   load*                 — щоденні лоадери ASC / Apple Ads / FX (src/loaders.ts)
import { readFileSync } from "fs";
import { join } from "path";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { BigQuery } from "@google-cloud/bigquery";
import { Environment, SignedDataVerifier } from "@apple/app-store-server-library";
import { lastDays, loadAppleAds, loadAscSales, loadAscSubscriber, loadFx } from "./loaders";

const REGION = "us-central1";
const BUNDLE_ID = "com.danetka.Danetka";
const APP_APPLE_ID = 6762550306;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const bq = new BigQuery();
const raw = bq.dataset("raw");

type Row = Record<string, unknown>;

async function insert(table: string, rows: Row[], insertIds?: string[]) {
  if (rows.length === 0) return;
  // raw: true — щоб передати insertId (best-effort дедуп ретраїв на боці BigQuery).
  await raw.table(table).insert(
    rows.map((json, i) => ({ json, insertId: insertIds?.[i] })),
    { raw: true },
  );
}

const iso = (ms?: number) => (ms ? new Date(ms).toISOString() : null);
const str = (v: unknown, max = 200) => (typeof v === "string" && v.length > 0 ? v.slice(0, max) : null);
const int = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? Math.trunc(v) : null);
const ts = (v: unknown) => {
  if (typeof v !== "string") return null;
  const d = new Date(v);
  return isNaN(d.getTime()) ? null : d.toISOString();
};

// ─────────────────────────────────────────────────────────────
// Застосунок
// ─────────────────────────────────────────────────────────────
export const ingest = onRequest({ region: REGION, maxInstances: 5, memory: "256MiB" }, async (req, res) => {
  if (req.method !== "POST") { res.status(405).end(); return; }
  const body = (req.body ?? {}) as Row;
  const userId = str(body.user_id, 36);
  if (!userId || !UUID_RE.test(userId)) { res.status(400).send("bad user_id"); return; }
  const receivedAt = new Date().toISOString();

  try {
    switch (req.path) {
      case "/app/install": {
        await insert("app_installs", [{
          user_id: userId,
          installed_at: ts(body.installed_at) ?? receivedAt,
          storefront: str(body.storefront, 3),
          locale: str(body.locale, 40),
          idfv: str(body.idfv, 36),
          app_version: str(body.app_version, 20),
          received_at: receivedAt,
        }], [`install:${userId}`]);
        break;
      }
      case "/app/attribution": {
        const a = (body.raw ?? {}) as Row;
        if (typeof a !== "object" || Array.isArray(a)) { res.status(400).send("bad raw"); return; }
        await insert("app_attribution", [{
          user_id: userId,
          received_at: receivedAt,
          attribution: typeof a.attribution === "boolean" ? a.attribution : null,
          org_id: int(a.orgId),
          campaign_id: int(a.campaignId),
          ad_group_id: int(a.adGroupId),
          keyword_id: int(a.keywordId),
          ad_id: int(a.adId),
          country_or_region: str(a.countryOrRegion, 2),
          click_date: ts(a.clickDate),
          conversion_type: str(a.conversionType, 40),
          claim_type: str(a.claimType, 40),
          supply_placement: str(a.supplyPlacement, 80),
          raw: JSON.stringify(a).slice(0, 4000),
        }], [`attribution:${userId}`]);
        break;
      }
      case "/app/txmap": {
        const ids = Array.isArray(body.original_transaction_ids) ? body.original_transaction_ids : [];
        const clean = ids.filter((id): id is string => typeof id === "string" && /^\d{1,30}$/.test(id)).slice(0, 50);
        await insert("app_transactions_map",
          clean.map((id) => ({ user_id: userId, original_transaction_id: id, received_at: receivedAt })),
          clean.map((id) => `txmap:${userId}:${id}`));
        break;
      }
      default:
        res.status(404).end();
        return;
    }
    res.status(204).end();
  } catch (e) {
    logger.error("ingest insert failed", { path: req.path, error: String(e) });
    res.status(500).end();   // застосунок залишить рядок у черзі й повторить
  }
});

// ─────────────────────────────────────────────────────────────
// App Store Server Notifications v2 (через Adapty)
// ─────────────────────────────────────────────────────────────
const appleRoots = [readFileSync(join(__dirname, "..", "certs", "AppleRootCA-G3.cer"))];
const verifiers = {
  Production: new SignedDataVerifier(appleRoots, true, Environment.PRODUCTION, BUNDLE_ID, APP_APPLE_ID),
  Sandbox: new SignedDataVerifier(appleRoots, true, Environment.SANDBOX, BUNDLE_ID),
};

/// Середина JWS без перевірки — лише щоб обрати verifier за environment; сама перевірка нижче.
function peekEnvironment(signedPayload: string): "Production" | "Sandbox" {
  const part = signedPayload.split(".")[1] ?? "";
  const payload = JSON.parse(Buffer.from(part, "base64url").toString("utf8"));
  return payload?.data?.environment === "Sandbox" ? "Sandbox" : "Production";
}

export const appstoreNotifications = onRequest({ region: REGION, maxInstances: 5, memory: "256MiB" }, async (req, res) => {
  if (req.method !== "POST") { res.status(405).end(); return; }
  const signedPayload = str((req.body ?? {}).signedPayload, 100_000);
  if (!signedPayload) { res.status(400).send("no signedPayload"); return; }

  let row: Row;
  try {
    const verifier = verifiers[peekEnvironment(signedPayload)];
    const n = await verifier.verifyAndDecodeNotification(signedPayload);
    const tx = n.data?.signedTransactionInfo
      ? await verifier.verifyAndDecodeTransaction(n.data.signedTransactionInfo) : undefined;
    const rn = n.data?.signedRenewalInfo
      ? await verifier.verifyAndDecodeRenewalInfo(n.data.signedRenewalInfo) : undefined;

    row = {
      notification_uuid: n.notificationUUID,
      received_at: new Date().toISOString(),
      signed_date: iso(n.signedDate),
      notification_type: n.notificationType ?? null,
      subtype: n.subtype ?? null,
      environment: n.data?.environment ?? null,
      app_account_token: tx?.appAccountToken?.toLowerCase() ?? null,
      original_transaction_id: tx?.originalTransactionId ?? rn?.originalTransactionId ?? null,
      transaction_id: tx?.transactionId ?? null,
      product_id: tx?.productId ?? rn?.productId ?? null,
      transaction_reason: tx?.transactionReason ?? null,
      offer_type: tx?.offerType ?? null,
      offer_discount_type: tx?.offerDiscountType ?? null,
      purchase_date: iso(tx?.purchaseDate),
      original_purchase_date: iso(tx?.originalPurchaseDate),
      expires_date: iso(tx?.expiresDate),
      revocation_date: iso(tx?.revocationDate),
      price_milli: tx?.price ?? null,
      currency: tx?.currency ?? null,
      storefront: tx?.storefront ?? null,
      auto_renew_status: rn?.autoRenewStatus ?? null,
      expiration_intent: rn?.expirationIntent ?? null,
      is_in_billing_retry: rn?.isInBillingRetryPeriod ?? null,
      grace_period_expires_date: iso(rn?.gracePeriodExpiresDate),
      payload: JSON.stringify({ notification: n, transaction: tx, renewal: rn }),
    };
  } catch (e) {
    // Невалідний підпис — 400: повтор не допоможе.
    logger.warn("notification rejected", { error: String(e) });
    res.status(400).end();
    return;
  }

  try {
    await insert("appstore_notifications", [row], [String(row.notification_uuid)]);
    res.status(200).end();
  } catch (e) {
    logger.error("notification insert failed", { uuid: row.notification_uuid, error: String(e) });
    res.status(500).end();   // Apple / Adapty повторять
  }
});

// ─────────────────────────────────────────────────────────────
// Щоденні лоадери (замість ручного analytics/loaders/README.md)
// ─────────────────────────────────────────────────────────────
// Вміст AuthKey_69AVX6PM25.p8 і apple-ads-private.pem — у Secret Manager, не в репо.
const ascKey = defineSecret("ASC_API_KEY");
const appleAdsKey = defineSecret("APPLE_ADS_PRIVATE_KEY");

// Apple переписує свіжі дні (ASC — пізні звіти, Apple Ads — атрибуція), тож щодня беремо тиждень.
const LOOKBACK_DAYS = 7;
const daily = (schedule: string, secrets: ReturnType<typeof defineSecret>[] = []) => ({
  region: REGION, schedule, timeZone: "UTC", retryCount: 2,
  timeoutSeconds: 540, memory: "512MiB" as const, maxInstances: 1, secrets,
});

// ASC daily-звіти за вчора з'являються ~8:00 PT; 404 за день не стирає наявні рядки.
export const loadAscSalesDaily = onSchedule(daily("0 17 * * *", [ascKey]),
  async () => loadAscSales(ascKey.value(), lastDays(LOOKBACK_DAYS)));

export const loadAscSubscriberDaily = onSchedule(daily("15 17 * * *", [ascKey]),
  async () => loadAscSubscriber(ascKey.value(), lastDays(LOOKBACK_DAYS)));

export const loadAppleAdsDaily = onSchedule(daily("0 7 * * *", [appleAdsKey]),
  async () => loadAppleAds(appleAdsKey.value(), lastDays(LOOKBACK_DAYS)));

export const loadFxDaily = onSchedule(daily("0 6 * * *"),
  async () => loadFx(lastDays(LOOKBACK_DAYS)));
