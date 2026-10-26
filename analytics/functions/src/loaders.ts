// Щоденні лоадери у BigQuery — порт analytics/loaders/*.py.
// Кожен лоадер перечитує останні дні (Apple переписує свіжі дати) і робить upsert по даті:
// одна транзакція DELETE дат + INSERT нових рядків, без --replace всієї таблиці.
// Ключі передаються аргументами: у функціях — з Secret Manager, у backfill.ts — з файлів.
import { sign } from "crypto";
import { writeFileSync, unlinkSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { gunzipSync } from "zlib";
import { logger } from "firebase-functions/v2";
import { BigQuery } from "@google-cloud/bigquery";

const bq = new BigQuery();
type Row = Record<string, unknown>;

// ─────────────────────────────────────────────────────────────
// Дати, JWT, пул
// ─────────────────────────────────────────────────────────────
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const DAY_MS = 86_400_000;
export const isoDay = (d: Date) => d.toISOString().slice(0, 10);
export const addDays = (day: string, n: number) => isoDay(new Date(Date.parse(day) + n * DAY_MS));

/// Дні [today − lookback, today − 1] за UTC, від найстаршого.
export function lastDays(lookback: number): string[] {
  const today = isoDay(new Date());
  return Array.from({ length: lookback }, (_, i) => addDays(today, i - lookback));
}

export function dayRange(start: string, end: string): string[] {
  const out: string[] = [];
  for (let d = start; d <= end; d = addDays(d, 1)) out.push(d);
  return out;
}

function es256Jwt(header: Row, payload: Row, pem: string): string {
  const b64 = (o: Row) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const data = `${b64({ alg: "ES256", ...header })}.${b64(payload)}`;
  const sig = sign("sha256", Buffer.from(data), { key: pem, dsaEncoding: "ieee-p1363" });
  return `${data}.${sig.toString("base64url")}`;
}

async function pool<T, R>(items: T[], size: number, fn: (t: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(size, items.length) }, async () => {
    while (next < items.length) { const i = next++; out[i] = await fn(items[i]); }
  }));
  return out;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const v = (x: string | undefined) => { const s = (x ?? "").trim(); return s || null; };

// ─────────────────────────────────────────────────────────────
// BigQuery upsert
// ─────────────────────────────────────────────────────────────
/// Видаляє `dates` у `dataset.table` і вставляє `rows` однією транзакцією.
/// Рядки спершу йдуть load job-ом у тимчасову staging-таблицю (не streaming insert —
/// рядки зі streaming buffer не можна видаляти DML-ом наступного дня).
export async function upsertByDate(dataset: string, table: string, dateCol: string, dates: string[], rows: Row[]) {
  if (dates.length === 0) { logger.info("upsert skipped: no dates", { table }); return; }
  for (const d of dates) if (!DATE_RE.test(d)) throw new Error(`bad date ${d}`);
  const ds = bq.dataset(dataset);
  const [meta] = await ds.table(table).getMetadata();
  const stageName = `_stage_${table}_${Date.now()}`;
  const [stage] = await ds.createTable(stageName, { schema: meta.schema, expirationTime: String(Date.now() + 3_600_000) });
  const file = join(tmpdir(), `${stageName}.ndjson`);
  try {
    if (rows.length > 0) {
      writeFileSync(file, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
      await stage.load(file, { sourceFormat: "NEWLINE_DELIMITED_JSON", writeDisposition: "WRITE_TRUNCATE" });
    }
    const cols = (meta.schema.fields as { name: string }[]).map((f) => `\`${f.name}\``).join(", ");
    const list = dates.map((d) => `DATE '${d}'`).join(", ");
    await bq.query({
      location: meta.location,
      query: `BEGIN TRANSACTION;
DELETE FROM \`${dataset}.${table}\` WHERE ${dateCol} IN (${list});
INSERT INTO \`${dataset}.${table}\` (${cols}) SELECT ${cols} FROM \`${dataset}.${stageName}\`;
COMMIT TRANSACTION;`,
    });
    logger.info("upsert done", { table, from: dates[0], to: dates[dates.length - 1], days: dates.length, rows: rows.length });
  } finally {
    try { unlinkSync(file); } catch { /* файлу могло не бути */ }
    await stage.delete().catch((e) => logger.warn("staging drop failed", { stageName, error: String(e) }));
  }
}

// ─────────────────────────────────────────────────────────────
// App Store Connect: Sales Reports (SALES SUMMARY, SUBSCRIBER DETAILED)
// ─────────────────────────────────────────────────────────────
const ASC_ISS = "6d7538b8-bc63-428c-8ec2-42cb6c43caf9";
const ASC_KID = "69AVX6PM25";
const ASC_VENDOR = "94139603";

const ascToken = (key: string) => {
  const now = Math.floor(Date.now() / 1000);
  return es256Jwt({ kid: ASC_KID, typ: "JWT" }, { iss: ASC_ISS, iat: now, exp: now + 1100, aud: "appstoreconnect-v1" }, key);
};

/// TSV-звіт за день або null, якщо Apple його (ще) не має (404).
async function ascReport(key: string, day: string, type: "SALES" | "SUBSCRIBER"): Promise<Row[] | null> {
  const params = new URLSearchParams({
    "filter[frequency]": "DAILY",
    "filter[reportType]": type,
    "filter[reportSubType]": type === "SALES" ? "SUMMARY" : "DETAILED",
    "filter[vendorNumber]": ASC_VENDOR,
    "filter[reportDate]": day,
    "filter[version]": type === "SALES" ? "1_1" : "1_3",
  });
  let last = "";
  for (let attempt = 0; attempt < 4; attempt++) {
    const r = await fetch(`https://api.appstoreconnect.apple.com/v1/salesReports?${params}`, {
      headers: { Authorization: `Bearer ${ascToken(key)}` },
    });
    if (r.status === 200) {
      const buf = Buffer.from(await r.arrayBuffer());
      const text = (buf[0] === 0x1f && buf[1] === 0x8b ? gunzipSync(buf) : buf).toString("utf8");
      const [head, ...lines] = text.split(/\r?\n/).filter((l) => l.trim() !== "");
      const cols = head.split("\t");
      return lines.map((l) => { const f = l.split("\t"); return Object.fromEntries(cols.map((c, i) => [c.trim(), f[i]])); });
    }
    if (r.status === 404) return null;
    last = `${r.status} ${(await r.text()).slice(0, 200)}`;
    await sleep(3000 * (attempt + 1));
  }
  throw new Error(`ASC ${type} ${day}: ${last}`);
}

const mdy = (x: string) => { const [m, d, y] = x.trim().split("/"); return `${y}-${m}-${d}`; };   // Apple пише MM/DD/YYYY

async function loadAsc(key: string, days: string[], type: "SALES" | "SUBSCRIBER") {
  const loadedAt = new Date().toISOString();
  const reports = await pool(days, 6, (d) => ascReport(key, d, type));
  // Видаляємо тільки дні, за які звіт прийшов: 404 за вчора не має стерти наявні дані.
  const got = days.filter((_, i) => reports[i] !== null);
  const rows: Row[] = reports.flatMap((rs) => (rs ?? []).map((r): Row => type === "SALES" ? {
    event_date: mdy(r["Begin Date"] as string), product_type: v(r["Product Type Identifier"] as string),
    sku: v(r["SKU"] as string), title: v(r["Title"] as string), apple_identifier: v(r["Apple Identifier"] as string),
    parent_identifier: v(r["Parent Identifier"] as string), version: v(r["Version"] as string),
    country: v(r["Country Code"] as string), device: v(r["Device"] as string),
    units: Math.trunc(Number(v(r["Units"] as string) ?? 0)), customer_price: v(r["Customer Price"] as string),
    customer_currency: v(r["Customer Currency"] as string), developer_proceeds: v(r["Developer Proceeds"] as string),
    proceeds_currency: v(r["Currency of Proceeds"] as string), promo_code: v(r["Promo Code"] as string),
    subscription: v(r["Subscription"] as string), period: v(r["Period"] as string),
    order_type: v(r["Order Type"] as string), loaded_at: loadedAt,
  } : {
    event_date: v(r["Event Date"] as string), subscriber_id: v(r["Subscriber ID"] as string),
    subscription_name: v(r["Subscription Name"] as string), subscription_apple_id: v(r["Subscription Apple ID"] as string),
    standard_duration: v(r["Standard Subscription Duration"] as string), offer_type: v(r["Subscription Offer Type"] as string),
    offer_duration: v(r["Subscription Offer Duration"] as string), customer_price: v(r["Customer Price"] as string),
    customer_currency: v(r["Customer Currency"] as string), developer_proceeds: v(r["Developer Proceeds"] as string),
    proceeds_currency: v(r["Proceeds Currency"] as string), proceeds_reason: v(r["Proceeds Reason"] as string),
    device: v(r["Device"] as string), country: v(r["Country"] as string), refund: v(r["Refund"] as string),
    purchase_date: v(r["Purchase Date"] as string), units: Math.trunc(Number(v(r["Units"] as string) ?? 0)), loaded_at: loadedAt,
  }));
  const stray = rows.filter((r) => !got.includes(r.event_date as string));
  if (stray.length > 0) logger.warn("rows outside fetched report dates", { type, count: stray.length, sample: stray[0].event_date });
  logger.info("asc fetched", { type, days: days.length, withReport: got.length, missing: days.filter((d) => !got.includes(d)) });
  await upsertByDate("raw", type === "SALES" ? "asc_sales_daily" : "asc_subscriber_daily", "event_date", got, rows);
}

export const loadAscSales = (key: string, days: string[]) => loadAsc(key, days, "SALES");
export const loadAscSubscriber = (key: string, days: string[]) => loadAsc(key, days, "SUBSCRIBER");

// ─────────────────────────────────────────────────────────────
// Курси валют → ref.fx_daily
// ─────────────────────────────────────────────────────────────
async function fxRates(day: string): Promise<Record<string, number> | null> {
  for (const url of [
    `https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@${day}/v1/currencies/usd.json`,
    `https://${day}.currency-api.pages.dev/v1/currencies/usd.json`,
  ]) {
    try {
      const r = await fetch(url, { signal: AbortSignal.timeout(30_000) });
      if (r.ok) return ((await r.json()) as { usd: Record<string, number> }).usd;
    } catch { /* пробуємо дзеркало */ }
  }
  return null;
}

export async function loadFx(days: string[]) {
  const rates = await pool(days, 8, fxRates);
  const got = days.filter((_, i) => rates[i] !== null);
  const rows: Row[] = [];
  got.forEach((day) => {
    for (const [cur, perUsd] of Object.entries(rates[days.indexOf(day)]!)) {
      const usd = 1 / perUsd;
      if (cur.length === 3 && perUsd && Number.isFinite(usd) && usd < 1e20) {
        rows.push({ date: day, currency: cur.toUpperCase(), usd_per_unit: usd.toFixed(9) });
      }
    }
  });
  logger.info("fx fetched", { days: days.length, missing: days.filter((d) => !got.includes(d)) });
  await upsertByDate("ref", "fx_daily", "date", got, rows);
}

// ─────────────────────────────────────────────────────────────
// Apple Ads (org 21082690, USD) → raw.apple_ads_keyword_daily
// ─────────────────────────────────────────────────────────────
const ADS_CLIENT = "SEARCHADS.9a079a92-2a52-480c-bb86-272371b0e497";
const ADS_KID = "49d9ffcc-ecc5-428d-9616-d10d3b4bfa3f";
const ADS_ORG = 21082690;
const ADS_API = "https://api.searchads.apple.com/api/v5";

type Money = { amount?: string; currency?: string };
type Gran = { date: string; impressions?: number; taps?: number; tapInstalls?: number; viewInstalls?: number; localSpend?: Money };
type ReportRow = { metadata: Record<string, any>; granularity?: Gran[] };

async function adsToken(key: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const secret = es256Jwt({ kid: ADS_KID }, { sub: ADS_CLIENT, iss: ADS_CLIENT, iat: now, exp: now + 3600, aud: "https://appleid.apple.com" }, key);
  const r = await fetch("https://appleid.apple.com/auth/oauth2/token", {
    method: "POST",
    body: new URLSearchParams({ grant_type: "client_credentials", client_id: ADS_CLIENT, client_secret: secret, scope: "searchadsorg" }),
  });
  if (!r.ok) throw new Error(`Apple Ads token ${r.status} ${(await r.text()).slice(0, 200)}`);
  return ((await r.json()) as { access_token: string }).access_token;
}

async function adsCall(token: string, path: string, body?: unknown): Promise<any> {
  let last = "";
  for (let attempt = 0; attempt < 4; attempt++) {
    const r = await fetch(`${ADS_API}/${path}`, {
      method: body ? "POST" : "GET",
      headers: { Authorization: `Bearer ${token}`, "X-AP-Context": `orgId=${ADS_ORG}`, "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (r.ok) return r.json();
    last = `${r.status} ${(await r.text()).slice(0, 300)}`;
    if (r.status !== 429 && r.status < 500) break;
    await sleep(3000 * (attempt + 1));
  }
  throw new Error(`Apple Ads ${path}: ${last}`);
}

/// Звіт API обмежений 90 днями — ріжемо [start, end] на вікна.
function adsWindows(start: string, end: string): [string, string][] {
  const out: [string, string][] = [];
  for (let s = start; s <= end; s = addDays(s, 90)) out.push([s, addDays(s, 89) < end ? addDays(s, 89) : end]);
  return out;
}

async function adsReport(token: string, path: string, start: string, end: string, groupBy: string[]): Promise<ReportRow[]> {
  const rows: ReportRow[] = [];
  for (const [s, e] of adsWindows(start, end)) {
    for (let offset = 0; ; offset += 1000) {
      const res = await adsCall(token, `reports/${path}`, {
        startTime: s, endTime: e, granularity: "DAILY", timeZone: "ORTZ",
        selector: { orderBy: [{ field: "localSpend", sortOrder: "DESCENDING" }], pagination: { offset, limit: 1000 } },
        groupBy, returnRecordsWithNoMetrics: false, returnRowTotals: false, returnGrandTotals: false,
      });
      rows.push(...(res.data.reportingDataResponse.row ?? []));
      if (offset + 1000 >= (res.pagination?.totalResults ?? 0)) break;
    }
  }
  return rows;
}

const spendOf = (g: Gran) => Number(g.localSpend?.amount ?? 0);

/// Keyword × країна × день, плюс залишок ad group − keywords (Search Tab, Search Match) з keyword_id = 0.
export async function loadAppleAds(key: string, days: string[]) {
  const [start, end] = [days[0], days[days.length - 1]];
  const token = await adsToken(key);
  const camps: { id: number; name: string }[] = (await adsCall(token, "campaigns?limit=1000")).data;
  const loadedAt = new Date().toISOString();
  const rows: Row[] = [];
  let kwTotal = 0, residualTotal = 0;

  for (const c of camps) {
    // spend, impressions, taps, tap_installs, view_installs по (date, ad group, country)
    const kw = new Map<string, number[]>();
    for (const row of await adsReport(token, `campaigns/${c.id}/keywords`, start, end, ["countryOrRegion"])) {
      const m = row.metadata;
      for (const g of row.granularity ?? []) {
        const spend = spendOf(g); kwTotal += spend;
        const k = `${g.date}|${m.adGroupId}|${m.countryOrRegion}`;
        const a = kw.get(k) ?? [0, 0, 0, 0, 0];
        a[0] += spend; a[1] += g.impressions ?? 0; a[2] += g.taps ?? 0; a[3] += g.tapInstalls ?? 0; a[4] += g.viewInstalls ?? 0;
        kw.set(k, a);
        rows.push({
          date: g.date, org_id: ADS_ORG, campaign_id: c.id, campaign_name: c.name,
          ad_group_id: m.adGroupId ?? null, ad_group_name: m.adGroupName ?? null, keyword_id: m.keywordId ?? null,
          keyword: m.keyword ?? null, match_type: m.matchType ?? null, country_or_region: m.countryOrRegion ?? null,
          impressions: g.impressions ?? null, taps: g.taps ?? null, tap_installs: g.tapInstalls ?? null,
          view_installs: g.viewInstalls ?? null, spend: spend.toFixed(2), currency: g.localSpend?.currency ?? null,
          loaded_at: loadedAt,
        });
      }
    }
    for (const row of await adsReport(token, `campaigns/${c.id}/adgroups`, start, end, ["countryOrRegion"])) {
      const m = row.metadata;
      for (const g of row.granularity ?? []) {
        const a = kw.get(`${g.date}|${m.adGroupId}|${m.countryOrRegion}`) ?? [0, 0, 0, 0, 0];
        const spend = spendOf(g) - a[0];
        const imp = (g.impressions ?? 0) - a[1], taps = (g.taps ?? 0) - a[2];
        const ti = (g.tapInstalls ?? 0) - a[3], vi = (g.viewInstalls ?? 0) - a[4];
        if (Math.abs(spend) < 0.005 && imp <= 0 && taps <= 0 && ti <= 0 && vi <= 0) continue;
        residualTotal += spend;
        rows.push({
          date: g.date, org_id: ADS_ORG, campaign_id: c.id, campaign_name: c.name,
          ad_group_id: m.adGroupId, ad_group_name: m.adGroupName ?? null, keyword_id: 0,
          keyword: "(no keyword)", match_type: "SEARCH_MATCH_OR_TAB", country_or_region: m.countryOrRegion ?? null,
          impressions: Math.max(imp, 0), taps: Math.max(taps, 0), tap_installs: Math.max(ti, 0), view_installs: Math.max(vi, 0),
          spend: spend.toFixed(2), currency: g.localSpend?.currency ?? null, loaded_at: loadedAt,
        });
      }
    }
  }

  // Звірка: keyword + залишок має дорівнювати spend кампаній.
  const ids = new Set(camps.map((c) => c.id));
  const campaignTotal = (await adsReport(token, "campaigns", start, end, []))
    .filter((r) => ids.has(r.metadata.campaignId))
    .reduce((sum, r) => sum + (r.granularity ?? []).reduce((s, g) => s + spendOf(g), 0), 0);
  const loaded = kwTotal + residualTotal;
  const log = Math.abs(loaded - campaignTotal) > 0.05 ? logger.warn : logger.info;
  log("apple ads fetched", { start, end, campaigns: camps.length, rows: rows.length,
    keywordSpend: kwTotal.toFixed(2), residualSpend: residualTotal.toFixed(2), campaignSpend: campaignTotal.toFixed(2) });

  // Увесь діапазон: день без жодного рядка означає нульовий spend, старі рядки треба прибрати.
  await upsertByDate("raw", "apple_ads_keyword_daily", "date", dayRange(start, end), rows);
}
