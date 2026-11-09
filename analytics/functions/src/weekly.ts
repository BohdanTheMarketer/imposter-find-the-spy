// Вкладка Weekly у таблиці imposter metrics: окупаємість і воронка ASA за тижневими когортами (тижні install, пн–нд, UTC).
//   weeklyPayback      — пн і чт о 08:30 Kyiv
//   weeklyPaybackCheck — пн о 12:30 Kyiv: якщо сьогодні вкладка ще не оновлювалась, оновлює
// Джерела:
//   spend, installs — mart.spend (Apple Ads), spend × (1 + VAT): Apple Ads виставляє рахунок з українським ПДВ
//   trials          — Adapty Analytics trials_new з ASA-кампанією (trial стартує в першу добу після install, тож дата trial ≈ когорта)
//   net, paid subs  — Adapty cohort з period_unit=day: денні когорти, період = 7 днів від install, тобто period 1 = D7.
//                     Refund Adapty віднімає.
//   прогноз D7      — для когорт, де D7 ще не закрився: факт Adapty + очікувані списання trial→sub з mart.renewals_due
//                     × шанс оплати (історія наших trials, які дожили до того ж віку без скасування) + billing retry × 25%.
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { BigQuery } from "@google-cloud/bigquery";
import { JWT } from "google-auth-library";

const TZ = "Europe/Kiev";
const REGION = "us-central1";
const SHEET_ID = "1Kdj2v-W7XDZAybH6TdXHWe61B_OaSWBnPff8xxf5tKI";
const TAB = "Weekly";
const FIRST_WEEK = "2026-09-21"; // перший тиждень з ASA-атрибуцією в Adapty (білд з Adapty SDK вийшов ~19.09)
const ADS_VAT = 0.2;
const BILLING_RETRY_CHANCE = 0.25;
// Згладжування шансу оплати trial: поки історії мало, тягнемо до PRIOR з вагою PRIOR_WEIGHT trials.
const PRIOR = 0.6;
const PRIOR_WEIGHT = 5;

const adaptyKey = defineSecret("ADAPTY_SECRET_KEY");
const sheetsKey = defineSecret("SHEETS_SA_KEY");
const bq = new BigQuery();
const ADAPTY = "https://api-admin.adapty.io/api/v1/client-api/metrics";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const addDays = (d: string, n: number) => new Date(Date.parse(d + "T00:00:00Z") + n * 86400e3).toISOString().slice(0, 10);
const mondayOf = (d: string) => addDays(d, -((new Date(d + "T00:00:00Z").getUTCDay() + 6) % 7));
const ddmm = (d: string) => `${d.slice(8, 10)}.${d.slice(5, 7)}`;
const kyivNow = () => new Date().toLocaleString("sv-SE", { timeZone: TZ }).slice(0, 16); // YYYY-MM-DD HH:MM
const div = (a: number, b: number) => (b ? a / b : "");

async function adapty(path: string, body: unknown) {
  for (let attempt = 0; ; attempt++) {
    const res = await fetch(`${ADAPTY}/${path}/`, {
      method: "POST",
      headers: { Authorization: `Api-Key ${adaptyKey.value()}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (res.status === 429 && attempt < 5) { await sleep(30e3); continue; }
    if (!res.ok) throw new Error(`adapty ${path} ${res.status}: ${(await res.text()).slice(0, 500)}`);
    return (await res.json()) as any;
  }
}

type Week = {
  start: string; spend: number; installs: number; trials: number;
  net_d7: number; net_total: number; payers: number; open: boolean; d7_closes: string;
  expected: number; pending: number;
};

async function collect(): Promise<Week[]> {
  // Останній повний тиждень — той, що закінчився в минулу неділю.
  const lastSunday = addDays(mondayOf(kyivNow().slice(0, 10)), -1);
  const weeks = new Map<string, Week>();
  for (let w = FIRST_WEEK; w <= lastSunday; w = addDays(w, 7)) {
    weeks.set(w, { start: w, spend: 0, installs: 0, trials: 0, net_d7: 0, net_total: 0, payers: 0,
      open: false, d7_closes: addDays(w, 12), expected: 0, pending: 0 });
  }
  const week = (d: string) => weeks.get(mondayOf(d));

  const [spendRows] = await bq.query({
    query: `SELECT CAST(DATE_TRUNC(date, WEEK(MONDAY)) AS STRING) wk, SUM(spend_usd) spend, SUM(installs) installs
            FROM mart.spend WHERE date BETWEEN DATE(@from) AND DATE(@to) GROUP BY 1`,
    params: { from: FIRST_WEEK, to: lastSunday }, location: "US",
  });
  for (const r of spendRows) {
    const w = weeks.get(r.wk);
    if (w) { w.spend = Number(r.spend) * (1 + ADS_VAT); w.installs = Number(r.installs); }
  }
  // Усі кампанії, що колись крутились — нові підхопляться самі.
  const [camps] = await bq.query({ query: "SELECT DISTINCT CAST(campaign_id AS STRING) id FROM mart.spend", location: "US" });
  const campaignIds = camps.map((c) => c.id as string);

  const cohort = await adapty("cohort", {
    filters: { date: [FIRST_WEEK, lastSunday], attribution_campaign: campaignIds }, period_unit: "day",
  });
  for (const s of cohort.data) {
    if (s.type !== "single") continue;
    const w = week(s.title);
    if (!w) continue;
    const p1 = s.values[0];
    w.net_d7 += p1?.net_revenue_usd ?? 0;
    w.net_total += s.total_net_revenue_usd ?? 0;
    w.payers += s.total_paid_subscribers ?? 0;
    if (!p1 || p1.currently_active_period) w.open = true;
  }

  await sleep(20e3); // rate limit Adapty
  const trials = await adapty("analytics", {
    chart_id: "trials_new", filters: { date: [FIRST_WEEK, lastSunday] }, period_unit: "day",
    segmentation_by: "attribution_campaign",
  });
  for (const sec of Object.values(trials.data) as any[]) {
    for (const s of sec.data) {
      if (s.type === "total" || !s.type) continue; // без кампанії = не ASA
      for (const p of s.values) { const w = week(p.x.slice(0, 10)); if (w) w.trials += p.y ?? 0; }
    }
  }

  const open = [...weeks.values()].filter((w) => w.open);
  if (open.length) {
    const [rows] = await bq.query({
      query: `
        WITH hist AS (  -- trials з відомим результатом
          SELECT t.trial_started_at s, t.trial_cancelled_at c, r.state IN ('paid', 'paid_late') paid
          FROM mart.trials t JOIN mart.renewals_due r ON r.original_transaction_id = t.original_transaction_id AND r.kind = 'trial'
          WHERE r.due_at < CURRENT_TIMESTAMP() AND r.state != 'pending'
        ),
        p AS (  -- очікувані в межах D7 списання trial→sub у ASA-юзерів відкритих когорт
          SELECT r.transaction_id, CAST(DATE_TRUNC(DATE(u.installed_at), WEEK(MONDAY)) AS STRING) wk, r.state,
            IFNULL(r.expected_net_usd, 0) net, TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), t.trial_started_at, HOUR) age_h
          FROM mart.users u
          JOIN mart.renewals_due r USING (user_id)
          JOIN mart.trials t ON t.original_transaction_id = r.original_transaction_id
          WHERE u.is_apple_ads AND r.kind = 'trial' AND r.state IN ('pending', 'billing_retry')
            AND r.due_at < TIMESTAMP_ADD(u.installed_at, INTERVAL 7 DAY)
            AND DATE(u.installed_at) BETWEEN DATE(@from) AND DATE(@to)
        ),
        pc AS (
          SELECT p.transaction_id, ANY_VALUE(p.wk) wk, ANY_VALUE(p.net) net,
            IF(ANY_VALUE(p.state) = 'billing_retry', @retry,
               (COUNTIF(h.paid AND (h.c IS NULL OR h.c > TIMESTAMP_ADD(h.s, INTERVAL p.age_h HOUR))) + @prior * @w)
               / (COUNTIF(h.c IS NULL OR h.c > TIMESTAMP_ADD(h.s, INTERVAL p.age_h HOUR)) + @w)) chance
          FROM p CROSS JOIN hist h GROUP BY 1
        )
        SELECT wk, COUNT(*) pending, SUM(net * chance) expected FROM pc GROUP BY 1`,
      params: { from: open[0].start, to: lastSunday, retry: BILLING_RETRY_CHANCE, prior: PRIOR, w: PRIOR_WEIGHT },
      location: "US",
    });
    for (const r of rows) {
      const w = weeks.get(r.wk);
      if (w?.open) { w.pending = Number(r.pending); w.expected = Number(r.expected); }
    }
  }
  return [...weeks.values()];
}

// ── Таблиця ────────────────────────────────────────────────────────────────
type Fmt = "usd" | "pct" | "int" | null;
type Line = { label: string; fmt: Fmt; cells: (number | string)[]; total: number | string };

function layout(weeks: Week[], updated: string) {
  const sum = (f: (w: Week) => number) => weeks.reduce((a, w) => a + f(w), 0);
  const line = (label: string, fmt: Fmt, f: (w: Week) => number | string, total: number | string): Line =>
    ({ label, fmt, cells: weeks.map(f), total });
  const T = {
    spend: sum((w) => w.spend), installs: sum((w) => w.installs), trials: sum((w) => w.trials),
    d7: sum((w) => w.net_d7), d7f: sum((w) => w.net_d7 + w.expected), net: sum((w) => w.net_total),
    payers: sum((w) => w.payers), pending: sum((w) => w.pending),
  };
  const header = ["Когорта (неделя install)", ...weeks.map((w) => `${ddmm(w.start)}–${ddmm(addDays(w.start, 6))}`), "Итого"];

  const payback: Line[] = [
    line("Статус D7", null, (w) => (w.open ? `открыт до ${ddmm(w.d7_closes)}` : "закрыт"), ""),
    line("Spend с VAT", "usd", (w) => w.spend, T.spend),
    line("Net D7 факт", "usd", (w) => w.net_d7, T.d7),
    line("ROAS D7 факт", "pct", (w) => div(w.net_d7, w.spend), div(T.d7, T.spend)),
    line("Net D7 прогноз", "usd", (w) => w.net_d7 + w.expected, T.d7f),
    line("ROAS D7 прогноз", "pct", (w) => div(w.net_d7 + w.expected, w.spend), div(T.d7f, T.spend)),
    line("Net на сегодня", "usd", (w) => w.net_total, T.net),
    line("ROAS на сегодня", "pct", (w) => div(w.net_total, w.spend), div(T.net, T.spend)),
  ];
  const funnel: Line[] = [
    line("Installs (Apple Ads)", "int", (w) => w.installs, T.installs),
    line("CPI с VAT", "usd", (w) => div(w.spend, w.installs), div(T.spend, T.installs)),
    line("Trials", "int", (w) => w.trials, T.trials),
    line("Install → trial", "pct", (w) => div(w.trials, w.installs), div(T.trials, T.installs)),
    line("Цена trial с VAT", "usd", (w) => div(w.spend, w.trials), div(T.spend, T.trials)),
    line("Paid subs", "int", (w) => w.payers, T.payers),
    line("Ждём списаний trial → sub", "int", (w) => w.pending, T.pending),
    line("Trial → paid", "pct", (w) => div(w.payers, w.trials), div(T.payers, T.trials)),
  ];

  const values: (string | number)[][] = [];
  const formats: { row: number; fmt: Fmt }[] = [];
  const bold: number[] = [];
  const push = (l: Line) => { formats.push({ row: values.length, fmt: l.fmt }); values.push([l.label, ...l.cells, l.total]); };

  values.push(["Окупаемость ASA по недельным когортам"]); bold.push(0);
  values.push(["Обновлено (Киев)", updated]);
  bold.push(values.length); values.push(header);
  payback.forEach(push);
  values.push([]);
  bold.push(values.length); values.push(["Воронка ASA по когортам"]);
  bold.push(values.length); values.push(header);
  funnel.forEach(push);
  values.push([]);
  values.push(["Spend — Apple Ads × 1.2 (VAT). Installs — Apple Ads. Trials, net, paid subs — Adapty, только юзеры с атрибуцией на ASA-кампанию; net после комиссии Apple, налогов и refund."]);
  values.push(["D7 — net за первые 7 дней от install каждого юзера. Прогноз — для когорт с открытым D7: факт + ожидаемые списания trial → sub × шанс оплаты (по истории наших trials) + billing retry × 25%. Для закрытых прогноз = факт."]);
  values.push(["Обновляется автоматически: пн 08:30 (проверка в 12:30) и чт 08:30, Киев."]);
  return { values, formats, bold, cols: header.length };
}

// ── Google Sheets API ──────────────────────────────────────────────────────
async function sheetsClient() {
  const key = JSON.parse(sheetsKey.value());
  const jwt = new JWT({ email: key.client_email, key: key.private_key, scopes: ["https://www.googleapis.com/auth/spreadsheets"] });
  const base = `https://sheets.googleapis.com/v4/spreadsheets/${SHEET_ID}`;
  return async (method: string, path: string, body?: unknown) => {
    const res = await jwt.request({ url: base + path, method: method as any, data: body });
    return res.data as any;
  };
}

async function tabId(api: Awaited<ReturnType<typeof sheetsClient>>) {
  const meta = await api("GET", "?fields=sheets.properties");
  const found = meta.sheets.find((s: any) => s.properties.title === TAB);
  if (found) return found.properties.sheetId as number;
  const r = await api("POST", ":batchUpdate", { requests: [{ addSheet: { properties: { title: TAB } } }] });
  return r.replies[0].addSheet.properties.sheetId as number;
}

async function lastUpdated(): Promise<string | null> {
  const api = await sheetsClient();
  const r = await api("GET", `/values/${encodeURIComponent(`${TAB}!B2`)}`).catch(() => null);
  return r?.values?.[0]?.[0] ?? null;
}

const PATTERN: Record<Exclude<Fmt, null>, { type: string; pattern: string }> = {
  usd: { type: "CURRENCY", pattern: "$#,##0.00" },
  pct: { type: "PERCENT", pattern: "0.0%" },
  int: { type: "NUMBER", pattern: "#,##0" },
};

async function write(weeks: Week[]) {
  const api = await sheetsClient();
  const sheetId = await tabId(api);
  const { values, formats, bold, cols } = layout(weeks, kyivNow());
  await api("POST", `/values/${encodeURIComponent(`${TAB}!A1:ZZ200`)}:clear`, {});
  await api("PUT", `/values/${encodeURIComponent(`${TAB}!A1`)}?valueInputOption=RAW`, { values });
  const range = (r: number, c0 = 1, c1 = cols) => ({ sheetId, startRowIndex: r, endRowIndex: r + 1, startColumnIndex: c0, endColumnIndex: c1 });
  const requests: unknown[] = [
    // скинути формат усього аркуша, щоб після зсуву рядків не лишалось старого
    { repeatCell: { range: { sheetId }, cell: { userEnteredFormat: {} }, fields: "userEnteredFormat" } },
    ...formats.filter((f) => f.fmt).map((f) => ({
      repeatCell: { range: range(f.row), cell: { userEnteredFormat: { numberFormat: PATTERN[f.fmt!], horizontalAlignment: "RIGHT" } },
        fields: "userEnteredFormat(numberFormat,horizontalAlignment)" },
    })),
    ...bold.map((r) => ({
      repeatCell: { range: range(r, 0), cell: { userEnteredFormat: { textFormat: { bold: true } } }, fields: "userEnteredFormat.textFormat.bold" },
    })),
    // колонка «Итого» жирним
    { repeatCell: { range: { sheetId, startRowIndex: 2, endRowIndex: values.length - 4, startColumnIndex: cols - 1, endColumnIndex: cols },
      cell: { userEnteredFormat: { textFormat: { bold: true } } }, fields: "userEnteredFormat.textFormat.bold" } },
    { updateSheetProperties: { properties: { sheetId, gridProperties: { frozenColumnCount: 1 } }, fields: "gridProperties.frozenColumnCount" } },
    { updateDimensionProperties: { range: { sheetId, dimension: "COLUMNS", startIndex: 0, endIndex: 1 }, properties: { pixelSize: 230 }, fields: "pixelSize" } },
    { updateDimensionProperties: { range: { sheetId, dimension: "COLUMNS", startIndex: 1, endIndex: cols }, properties: { pixelSize: 110 }, fields: "pixelSize" } },
  ];
  await api("POST", ":batchUpdate", { requests });
  logger.info("weekly sheet updated", { weeks: weeks.length, rows: values.length });
}

export async function updateWeekly() {
  await write(await collect());
}

const opts = { timeZone: TZ, region: REGION, secrets: [adaptyKey, sheetsKey], timeoutSeconds: 300, retryCount: 1 };

export const WEEKLY_URL = `https://docs.google.com/spreadsheets/d/${SHEET_ID}/edit#gid=1305537659`;
export const WEEKLY_DAYS = ["Mon", "Thu"]; // має збігатися з розкладом weeklyPayback

// 08:30 — після refreshWarehouse (06:00) і до Telegram-звіту revenueForecast (09:00), який у ці дні дає посилання.
export const weeklyPayback = onSchedule({ ...opts, schedule: "30 8 * * 1,4" }, updateWeekly);

export const weeklyPaybackCheck = onSchedule({ ...opts, schedule: "30 12 * * 1" }, async () => {
  const today = kyivNow().slice(0, 10);
  const last = await lastUpdated();
  if (last?.startsWith(today)) { logger.info("weekly sheet already updated today", { last }); return; }
  logger.warn("weekly sheet not updated at 10:30, updating now", { last });
  await updateWeekly();
});
