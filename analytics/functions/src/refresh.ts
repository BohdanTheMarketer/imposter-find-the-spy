// Щоденне оновлення сховища із зовнішніх API — те саме, що loaders/*.py, тільки без ручного запуску.
// Кожне джерело перезаливає останні DAYS днів: Apple Ads, ASC і Adapty дописують дані заднім числом.
//   refreshWarehouse — Apple Ads spend, ASC SUBSCRIBER / SALES, курси валют
//   refreshAdapty    — Adapty Analytics API, src/adapty.ts (окремо: rate limit, ~5 хв)
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { BigQuery } from "@google-cloud/bigquery";
import { writeFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gunzipSync } from "node:zlib";
import { ADS, ASC, adsHeaders, adsReport, ascToken } from "./apple";

const TZ = "Europe/Kiev"; // лише розклад; дні в BigQuery — UTC, як в Adapty
const REGION = "us-central1";
export const DAYS = 7;
const adsKey = defineSecret("APPLE_ADS_PRIVATE_KEY");
const ascKey = defineSecret("ASC_API_KEY");

const bq = new BigQuery();

export type Row = Record<string, unknown>;

// Дати [yesterday - n + 1 … yesterday] за UTC, YYYY-MM-DD.
export function lastDays(n: number) {
  return Array.from({ length: n }, (_, i) =>
    new Date(Date.now() - (n - i) * 86400e3).toISOString().slice(0, 10));
}

// Атомарна заміна днів: load у staging-копію таблиці, потім DELETE + INSERT в одній транзакції.
// Load, а не streaming insert — щоб DML не впирався в streaming buffer.
export async function replaceDays(dataset: string, table: string, dateCol: string, days: string[], rows: Row[]) {
  if (!days.length) return;
  const stage = `_stage_${table}`;
  await bq.query({ query: `CREATE OR REPLACE TABLE ${dataset}.${stage} LIKE ${dataset}.${table}`, location: "US" });
  if (rows.length) {
    const file = join(tmpdir(), `${stage}.ndjson`);
    writeFileSync(file, rows.map((r) => JSON.stringify(r)).join("\n"));
    try {
      await bq.dataset(dataset).table(stage).load(file, { sourceFormat: "NEWLINE_DELIMITED_JSON", writeDisposition: "WRITE_APPEND" });
    } finally {
      unlinkSync(file);
    }
  }
  await bq.query({
    query: `
      BEGIN TRANSACTION;
      DELETE FROM ${dataset}.${table} WHERE ${dateCol} IN (SELECT DATE(d) FROM UNNEST(@days) AS d);
      INSERT INTO ${dataset}.${table} SELECT * FROM ${dataset}.${stage};
      COMMIT TRANSACTION;
      DROP TABLE ${dataset}.${stage};`,
    // Масив як рядки: з types DATE клієнт @google-cloud/bigquery передає дати так, що збігів 0.
    params: { days },
    location: "US",
  });
  logger.info(`refreshed ${dataset}.${table}`, { days: `${days[0]}…${days[days.length - 1]}`, rows: rows.length });
}

// ── Курси валют (як loaders/fx_fetch.py) ─────────────────────────────────────
async function fxDay(d: string): Promise<Row[] | null> {
  for (const url of [
    `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@${d}/v1/currencies/usd.json`,
    `https://${d}.currency-api.pages.dev/v1/currencies/usd.json`,
  ]) {
    const res = await fetch(url).catch(() => null);
    if (!res?.ok) continue;
    const { usd } = await res.json() as { usd: Record<string, number> };
    return Object.entries(usd)
      .filter(([cur, perUsd]) => cur.length === 3 && perUsd)
      .map(([cur, perUsd]) => ({ date: d, currency: cur.toUpperCase(), usd_per_unit: (1 / perUsd).toFixed(9) }));
  }
  return null;
}

async function refreshFx() {
  const got = await Promise.all(lastDays(DAYS).map(async (d) => [d, await fxDay(d)] as const));
  const ok = got.filter(([, rows]) => rows);
  await replaceDays("ref", "fx_daily", "date", ok.map(([d]) => d), ok.flatMap(([, rows]) => rows!));
}

// ── Apple Ads spend keyword × країна × день (як apple_ads_keywords_fetch.py + residual) ──
async function refreshAppleAds() {
  const days = lastDays(DAYS);
  const [from, to] = [days[0], days[days.length - 1]];
  const headers = await adsHeaders(adsKey.value());
  const campRes = await fetch(`${ADS.api}/campaigns?limit=1000`, { headers });
  if (!campRes.ok) throw new Error(`apple ads campaigns ${campRes.status}: ${await campRes.text()}`);
  const camps = (await campRes.json() as { data: { id: number; name: string; supplySources?: string[] }[] }).data;
  const loaded_at = new Date().toISOString();
  const rows: Row[] = [];

  for (const c of camps) {
    const base = { org_id: ADS.org, campaign_id: c.id, campaign_name: c.name, loaded_at };
    // Сума keyword-рядків по ad group × країна × день — щоб знайти spend без keyword.
    const kwSum = new Map<string, number[]>();
    // Search Tab кампанії keywords не мають — API на запит відповідає 400; весь їх spend іде в keyword_id = 0.
    const searchTab = c.supplySources?.includes("APPSTORE_SEARCH_TAB");
    for (const row of searchTab ? [] : await adsReport(headers, `campaigns/${c.id}/keywords`, from, to, ["countryOrRegion"])) {
      const m = row.metadata;
      for (const g of row.granularity ?? []) {
        const spend = Number(g.localSpend?.amount ?? 0);
        const k = `${g.date}|${m.adGroupId}|${m.countryOrRegion}`;
        const a = kwSum.get(k) ?? [0, 0, 0, 0, 0];
        [spend, g.impressions ?? 0, g.taps ?? 0, g.tapInstalls ?? 0, g.viewInstalls ?? 0].forEach((v, i) => (a[i] += v));
        kwSum.set(k, a);
        rows.push({
          ...base, date: g.date, ad_group_id: m.adGroupId, ad_group_name: m.adGroupName, keyword_id: m.keywordId,
          keyword: m.keyword, match_type: m.matchType, country_or_region: m.countryOrRegion,
          impressions: g.impressions, taps: g.taps, tap_installs: g.tapInstalls, view_installs: g.viewInstalls,
          spend: spend.toFixed(2), currency: g.localSpend?.currency,
        });
      }
    }
    // Search Tab і Search Match не мають keyword: ad group − keywords → keyword_id = 0.
    for (const row of await adsReport(headers, `campaigns/${c.id}/adgroups`, from, to, ["countryOrRegion"])) {
      const m = row.metadata;
      for (const g of row.granularity ?? []) {
        const a = kwSum.get(`${g.date}|${m.adGroupId}|${m.countryOrRegion}`) ?? [0, 0, 0, 0, 0];
        const spend = Number(g.localSpend?.amount ?? 0) - a[0];
        const [imp, taps, ti, vi] = [g.impressions, g.taps, g.tapInstalls, g.viewInstalls].map((v, i) => (v ?? 0) - a[i + 1]);
        if (Math.abs(spend) < 0.005 && imp <= 0 && taps <= 0 && ti <= 0 && vi <= 0) continue;
        rows.push({
          ...base, date: g.date, ad_group_id: m.adGroupId, ad_group_name: m.adGroupName, keyword_id: 0,
          keyword: "(no keyword)", match_type: "SEARCH_MATCH_OR_TAB", country_or_region: m.countryOrRegion,
          impressions: Math.max(imp, 0), taps: Math.max(taps, 0), tap_installs: Math.max(ti, 0), view_installs: Math.max(vi, 0),
          spend: spend.toFixed(2), currency: g.localSpend?.currency,
        });
      }
    }
  }
  await replaceDays("raw", "apple_ads_keyword_daily", "date", days, rows);
}

// ── App Store Connect Sales Reports (як asc_subscriber_fetch.py / asc_sales_fetch.py) ──
const v = (x?: string) => (x ?? "").trim() || null;

async function ascReport(token: string, d: string, type: "SUBSCRIBER" | "SALES") {
  const params = new URLSearchParams({
    "filter[frequency]": "DAILY", "filter[reportType]": type,
    "filter[reportSubType]": type === "SALES" ? "SUMMARY" : "DETAILED",
    "filter[vendorNumber]": ASC.vendor, "filter[reportDate]": d, "filter[version]": type === "SALES" ? "1_1" : "1_3",
  });
  const res = await fetch(`https://api.appstoreconnect.apple.com/v1/salesReports?${params}`, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 404) return null; // звіт ще не готовий — день не чіпаємо
  if (!res.ok) throw new Error(`asc ${type} ${d} ${res.status}: ${await res.text()}`);
  const [head, ...lines] = gunzipSync(Buffer.from(await res.arrayBuffer())).toString().split("\n").map((l) => l.replace(/\r$/, ""));
  const cols = head.split("\t");
  return lines.filter(Boolean).map((l) => {
    const cells = l.split("\t");
    return Object.fromEntries(cols.map((c, i) => [c, cells[i]]));
  });
}

async function refreshAsc() {
  const token = ascToken(ascKey.value());
  const loaded_at = new Date().toISOString();
  const days = lastDays(DAYS);
  const [subs, sales] = await Promise.all(["SUBSCRIBER", "SALES"].map((type) =>
    Promise.all(days.map(async (d) => [d, await ascReport(token, d, type as "SUBSCRIBER" | "SALES")] as const))));

  const subDays = subs.filter(([, r]) => r);
  await replaceDays("raw", "asc_subscriber_daily", "event_date", subDays.map(([d]) => d), subDays.flatMap(([, rows]) => rows!.map((r) => ({
    event_date: v(r["Event Date"]), subscriber_id: v(r["Subscriber ID"]),
    subscription_name: v(r["Subscription Name"]), subscription_apple_id: v(r["Subscription Apple ID"]),
    standard_duration: v(r["Standard Subscription Duration"]), offer_type: v(r["Subscription Offer Type"]),
    offer_duration: v(r["Subscription Offer Duration"]), customer_price: v(r["Customer Price"]),
    customer_currency: v(r["Customer Currency"]), developer_proceeds: v(r["Developer Proceeds"]),
    proceeds_currency: v(r["Proceeds Currency"]), proceeds_reason: v(r["Proceeds Reason"]),
    device: v(r["Device"]), country: v(r["Country"]), refund: v(r["Refund"]),
    purchase_date: v(r["Purchase Date"]), units: Math.trunc(Number(v(r["Units"]) ?? 0)), loaded_at,
  }))));

  // Apple пише Begin Date як MM/DD/YYYY
  const mdy = (x?: string) => { const [m, d, y] = (x ?? "").trim().split("/"); return `${y}-${m}-${d}`; };
  const salesDays = sales.filter(([, r]) => r);
  await replaceDays("raw", "asc_sales_daily", "event_date", salesDays.map(([d]) => d), salesDays.flatMap(([, rows]) => rows!.map((r) => ({
    event_date: mdy(r["Begin Date"]), product_type: v(r["Product Type Identifier"]),
    sku: v(r["SKU"]), title: v(r["Title"]), apple_identifier: v(r["Apple Identifier"]),
    parent_identifier: v(r["Parent Identifier"]), version: v(r["Version"]),
    country: v(r["Country Code"]), device: v(r["Device"]),
    units: Math.trunc(Number(v(r["Units"]) ?? 0)), customer_price: v(r["Customer Price"]),
    customer_currency: v(r["Customer Currency"]), developer_proceeds: v(r["Developer Proceeds"]),
    proceeds_currency: v(r["Currency of Proceeds"]), promo_code: v(r["Promo Code"]),
    subscription: v(r["Subscription"]), period: v(r["Period"]), order_type: v(r["Order Type"]), loaded_at,
  }))));
}

// Падіння одного джерела не зупиняє інші; функція падає в кінці, щоб це було видно в логах / алертах.
async function runAll(jobs: Record<string, () => Promise<void>>) {
  const res = await Promise.allSettled(Object.values(jobs).map((f) => f()));
  const failed = Object.keys(jobs).filter((_, i) => res[i].status === "rejected");
  res.forEach((r, i) => r.status === "rejected" && logger.error(`refresh ${Object.keys(jobs)[i]} failed`, r.reason));
  if (failed.length) throw new Error(`refresh failed: ${failed.join(", ")}`);
}

export async function refreshAll() {
  await runAll({ fx: refreshFx, appleAds: refreshAppleAds, asc: refreshAsc });
}

// 06:00 — до ранкового revenueForecast (09:00).
export const refreshWarehouse = onSchedule(
  { schedule: "0 6 * * *", timeZone: TZ, region: REGION, secrets: [adsKey, ascKey], timeoutSeconds: 540, memory: "512MiB" },
  refreshAll,
);
