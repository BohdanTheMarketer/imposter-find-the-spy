// Щоранку в Telegram: прогноз net на сьогодні з mart.renewals_due.
// День — UTC (таймзона дашборду Adapty, змінити її не можна) і оплата за purchase_date нового періоду, як у дашборді Adapty (Apple списує ~8 год раніше,
// тож на момент звіту частина «сьогоднішніх» оплат уже пройшла).
//   прогноз = вже оплачені періоди, що закінчуються сьогодні
//           + ще не оплачені з auto-renew × історична частка оплат (за 30 днів, зі згладжуванням)
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { BigQuery } from "@google-cloud/bigquery";
import { adsHeaders, adsReport } from "./apple";

const TZ = "Europe/Kiev"; // розклад і час окремих оплат у тексті
const DAY_TZ = "UTC";     // межі днів — як в Adapty
const botToken = defineSecret("TELEGRAM_BOT_TOKEN");
const chatId = defineSecret("TELEGRAM_CHAT_ID");
const adsKey = defineSecret("APPLE_ADS_PRIVATE_KEY");

// Apple Ads виставляє рахунок з українським ПДВ — справжня ціна трафіку = spend × (1 + VAT).
const ADS_VAT = 0.2;

const bq = new BigQuery();

// Поки власних даних мало, частка оплат тягнеться до цих значень (вага — PRIOR_WEIGHT періодів).
const PRIOR = { trial: 0.85, renewal: 0.9 };
const PRIOR_WEIGHT = 10;

const SQL = `
WITH due AS (
  SELECT * FROM mart.renewals_due WHERE DATE(due_at, '${DAY_TZ}') = CURRENT_DATE('${DAY_TZ}')
),
hist AS (
  SELECT kind,
    COUNTIF(state IN ('paid', 'paid_late')) AS ok,
    COUNTIF(state IN ('paid', 'paid_late', 'billing_retry', 'lapsed')) AS n
  FROM mart.renewals_due
  WHERE due_at < CURRENT_TIMESTAMP()
    AND due_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    AND NOT STARTS_WITH(transaction_id, 'prev:')
  GROUP BY kind
)
SELECT
  k AS kind,
  COUNT(due.kind)                                        AS total,
  COUNTIF(due.state IN ('paid', 'paid_late'))              AS paid,
  IFNULL(SUM(due.paid_net_usd), 0)                         AS paid_usd,
  -- Adapty показує оплату лише з purchase_date, хоча Apple списав раніше
  IFNULL(SUM(IF(due.paid_at > CURRENT_TIMESTAMP(), due.paid_net_usd, 0)), 0) AS paid_ahead_usd,
  COUNTIF(due.state = 'pending')                           AS pending,
  IFNULL(SUM(IF(due.state = 'pending', due.expected_net_usd, 0)), 0) AS pending_usd,
  COUNTIF(due.state = 'billing_retry')                     AS billing_retry,
  COUNTIF(due.state IN ('cancelled', 'lapsed'))            AS cancelled,
  ANY_VALUE(hist.ok) AS hist_ok, ANY_VALUE(hist.n) AS hist_n
FROM UNNEST(['trial', 'renewal']) AS k
LEFT JOIN due  ON due.kind = k
LEFT JOIN hist ON hist.kind = k
GROUP BY k`;

const EXTRA_SQL = `
SELECT
  (SELECT COUNT(*) FROM mart.subscription_events
    WHERE event = 'trial_started' AND DATE(event_at, '${DAY_TZ}') = CURRENT_DATE('${DAY_TZ}')) AS trials_today,
  (SELECT COUNT(*) FROM mart.renewals_due
    WHERE paid_at IS NOT NULL AND DATE(paid_at, '${DAY_TZ}') = DATE_SUB(CURRENT_DATE('${DAY_TZ}'), INTERVAL 1 DAY)) AS paid_yesterday,
  (SELECT IFNULL(SUM(paid_net_usd), 0) FROM mart.renewals_due
    WHERE paid_at IS NOT NULL AND DATE(paid_at, '${DAY_TZ}') = DATE_SUB(CURRENT_DATE('${DAY_TZ}'), INTERVAL 1 DAY)) AS paid_yesterday_usd`;

// Поштучно сьогоднішні оплати, які ще не видно в Adapty: очікувані і вже списані наперед.
// Ціна в USD gross — щоб було видно, за скільки списання (старі підписники лишились на старій ціні ~$5, нові — ~$10).
const DETAIL_SQL = `
WITH fx AS (
  SELECT currency, usd_per_unit FROM ref.fx_daily
  QUALIFY ROW_NUMBER() OVER (PARTITION BY currency ORDER BY date DESC) = 1
),
d AS (
  SELECT r.*, r.state = 'pending' AS pending,
    IF(r.state = 'pending', r.expected_local, r.paid_local)       AS price_local,
    IF(r.state = 'pending', r.expected_currency, r.paid_currency) AS currency,
    IF(r.state = 'pending', r.expected_net_usd, r.paid_net_usd)   AS net_usd
  FROM mart.renewals_due r
  WHERE DATE(r.due_at, '${DAY_TZ}') = CURRENT_DATE('${DAY_TZ}')
    AND (r.state = 'pending' OR r.paid_at > CURRENT_TIMESTAMP())
)
SELECT d.original_transaction_id, d.due_at, d.kind, d.pending, COALESCE(st.country, d.storefront) AS country,
  FORMAT_TIMESTAMP('%H:%M', d.due_at, '${TZ}') AS due_time,
  d.price_local, d.currency, d.price_local * IF(d.currency = 'USD', 1, fx.usd_per_unit) AS price_usd, d.net_usd
FROM d
LEFT JOIN fx ON fx.currency = d.currency
LEFT JOIN ref.storefront st ON st.storefront = d.storefront
ORDER BY d.due_at`;

type DetailRow = {
  original_transaction_id: string; due_at: { value: string };
  kind: "trial" | "renewal"; pending: boolean; country: string; due_time: string;
  price_local: number; currency: string; price_usd: number | null; net_usd: number;
};

const KIND_LABEL = { trial: "тріал → підписка", renewal: "продовження" };

function detail(r: DetailRow) {
  const price = r.currency === "USD" || r.price_usd === null
    ? `${r.price_local} ${r.currency}`
    : `${usd(r.price_usd)} (${r.price_local} ${r.currency})`;
  return `   • ${r.due_time} ${KIND_LABEL[r.kind]}, ${r.country}: ${price} → ${usd(r.net_usd)} net`;
}

// Тріали, що стартували вчора; «живі» — не скасовані зараз. Net першого списання — ціна підписки
// після тріалу в країні покупця (expected_net_usd з mart.renewals_due).
const MARKETING_SQL = `
SELECT
  COUNT(*)                                             AS trials,
  COUNTIF(t.not_cancelled)                             AS live,
  IFNULL(SUM(IF(t.not_cancelled, r.expected_net_usd, 0)), 0) AS live_net_usd
FROM mart.trials t
LEFT JOIN mart.renewals_due r ON r.original_transaction_id = t.original_transaction_id AND r.kind = 'trial'
WHERE DATE(t.trial_started_at, '${DAY_TZ}') = DATE_SUB(CURRENT_DATE('${DAY_TZ}'), INTERVAL 1 DAY)`;

type MarketingRow = { trials: number; live: number; live_net_usd: number };

// Вчорашній прогноз (raw.forecast_daily) проти факту: що сталося з кожною оплатою, на яку чекали.
// failed — Apple пробував списати і не зміг (DID_FAIL_TO_RENEW біля due_at), навіть якщо потім скасували.
const REVIEW_SQL = `
WITH f AS (
  SELECT * FROM raw.forecast_daily WHERE date = DATE_SUB(CURRENT_DATE('${DAY_TZ}'), INTERVAL 1 DAY)
  QUALIFY ROW_NUMBER() OVER (ORDER BY created_at DESC) = 1
),
fact AS (
  SELECT IFNULL(SUM(paid_net_usd), 0) AS fact_usd FROM mart.renewals_due
  WHERE DATE(due_at, '${DAY_TZ}') = DATE_SUB(CURRENT_DATE('${DAY_TZ}'), INTERVAL 1 DAY)
),
fails AS (
  SELECT DISTINCT original_transaction_id, DATE(event_at, '${DAY_TZ}') AS date FROM mart.subscription_events
  WHERE notification_type = 'DID_FAIL_TO_RENEW'
),
items AS (
  SELECT p.*, IFNULL(r.state, 'pending') AS state, IFNULL(r.paid_net_usd, 0) AS paid_usd,
    fl.original_transaction_id IS NOT NULL AS failed
  FROM f, UNNEST(f.pending) p
  LEFT JOIN mart.renewals_due r ON r.original_transaction_id = p.original_transaction_id AND r.due_at = p.due_at
  LEFT JOIN fails fl ON fl.original_transaction_id = p.original_transaction_id AND fl.date = DATE(p.due_at, '${DAY_TZ}')
)
SELECT f.forecast_usd, fact.fact_usd,
  ARRAY(SELECT AS STRUCT i.kind, i.country, i.net_usd, i.chance, FORMAT_TIMESTAMP('%H:%M', i.due_at, '${TZ}') AS due_time,
          i.state, i.paid_usd, i.failed FROM items i ORDER BY i.due_at) AS items
FROM f, fact`;

type ReviewItem = {
  kind: "trial" | "renewal"; country: string; net_usd: number; chance: number; due_time: string;
  state: string; paid_usd: number; failed: boolean;
};
type ReviewRow = { forecast_usd: number; fact_usd: number; items: ReviewItem[] };

function outcome(i: ReviewItem) {
  if (i.state === "paid" || i.state === "paid_late") return `✅ оплатив ${usd(i.paid_usd)}`;
  if (i.state === "pending") return "⏳ ще не списалось";
  if (i.failed && i.state === "billing_retry") return "💳 Apple не зміг списати гроші з картки, ще пробуватиме кілька днів";
  if (i.failed) return "💳 Apple не зміг списати гроші з картки, після цього підписку скасували";
  return "❌ вимкнув автопродовження до списання";
}

function review(r: ReviewRow | undefined) {
  if (!r) return [];
  const diff = r.fact_usd - r.forecast_usd;
  const head = `<b>🔍 Вчора: прогноз ${usd(r.forecast_usd)} → факт ${usd(r.fact_usd)}</b>`;
  if (Math.abs(diff) < Math.max(1, r.forecast_usd * 0.05)) return [`${head} — прогноз справдився 🎯`];
  const lines = [`${head} (${diff >= 0 ? "+" : "−"}${usd(Math.abs(diff))})`];
  // Внесок кожної оплати: факт мінус те, що на неї закладали (net × шанс).
  let explained = 0;
  for (const i of r.items) {
    const delta = i.paid_usd - i.net_usd * i.chance;
    explained += delta;
    lines.push(`   • ${i.due_time} ${KIND_LABEL[i.kind]}, ${i.country}: ${outcome(i)} ` +
      `(закладали ${usd(i.net_usd * i.chance)}, ${delta >= 0 ? "+" : "−"}${usd(Math.abs(delta))})`);
  }
  const rest = diff - explained;
  if (Math.abs(rest) >= 0.5) {
    lines.push(`   • інше ${rest >= 0 ? "+" : "−"}${usd(Math.abs(rest))} — оплати, яких на ранок ще не було видно, або повернення`);
  }
  return lines;
}

// Spend усіх кампаній за UTC-день (як тріали в Adapty), USD без VAT. Напряму з API, а не з BigQuery:
// о 09:00 тут свіжіше, ніж у raw.apple_ads_keyword_daily після refreshWarehouse о 06:00.
async function adsSpend(date: string): Promise<number> {
  const rows = await adsReport(await adsHeaders(adsKey.value()), "campaigns", date, date);
  return rows.flatMap((r) => r.granularity ?? []).reduce((s, g) => s + Number(g.localSpend?.amount ?? 0), 0);
}

function marketing(m: MarketingRow, spend: number | null) {
  const lines = ["<b>📣 Marketing вчора</b>"];
  if (spend === null) return [...lines, "Spend: Apple Ads не відповів, див. логи"].join("\n");
  const cost = spend * (1 + ADS_VAT);
  lines.push(`💸 Spend: ${usd(cost)} з VAT ${Math.round(ADS_VAT * 100)}% (${usd(spend)} без VAT)`);
  lines.push(`🎯 CPT: ${m.trials ? usd(cost / m.trials) : "—"} (тріалів: ${m.trials}, живих: ${m.live})`);
  lines.push(`🔮 Predicted Cohort ROAS 3d: ${cost ? `${Math.round((m.live_net_usd / cost) * 100)}%` : "—"}` +
    ` (${m.live} × net підписки = ${usd(m.live_net_usd)} / spend з VAT)`);
  return lines.join("\n");
}

type KindRow = {
  kind: "trial" | "renewal";
  total: number; paid: number; paid_usd: number; paid_ahead_usd: number;
  pending: number; pending_usd: number;
  billing_retry: number; cancelled: number;
  hist_ok: number | null; hist_n: number | null;
};

const usd = (v: number) => `$${v.toFixed(2)}`;
const round2 = (v: number) => Math.round(v * 100) / 100;

const pick = <T>(xs: T[]) => xs[Math.floor(Math.random() * xs.length)];

// Нульові рядки ховаємо, щоб не читати «0, 0, 0».
function section(title: string, paidLabel: string, r: KindRow, rate: number) {
  if (!r.total) return `<b>${title}:</b> сьогодні нікого`;
  const lines = [`<b>${title}: ${r.total}</b>`];
  if (r.paid) lines.push(`✅ ${paidLabel}: ${r.paid} — ${usd(r.paid_usd)}`);
  if (r.pending) lines.push(`⏳ чекають списання: ${r.pending} (шанс оплати ${Math.round(rate * 100)}%)`);
  if (r.billing_retry) lines.push(`🔁 billing retry: ${r.billing_retry}`);
  if (r.cancelled) lines.push(`❌ скасували: ${r.cancelled}`);
  return lines.join("\n");
}

// Частини рахуємо від округлених сум, щоб у повідомленні складалось до цента.
function paidLines(already: number, ahead: number, rows: DetailRow[]) {
  if (!ahead) return [`✅ Вже списано: ${usd(already)} net — усе вже видно в Adapty`];
  return [
    `✅ Вже списано: ${usd(already)} net`,
    `   • в Adapty вже видно: ${usd(already - ahead)}`,
    `   • ще ${usd(round2(already) - round2(already - ahead))} Apple вже списав, але в Adapty поки не відображається — ` +
      `Adapty показує оплату з початку нового періоду, а Apple списує гроші ~на 8 год раніше:`,
    ...rows.map((r) => `   ${detail(r)}`),
  ];
}

function pendingLines(expected: number, rows: DetailRow[], rate: (k: DetailRow["kind"]) => number) {
  if (!rows.length) return ["⏳ Більше сьогодні нічого не чекаємо"];
  const chances = (["trial", "renewal"] as const)
    .filter((k) => rows.some((r) => r.kind === k))
    .map((k) => `${KIND_LABEL[k]} ${Math.round(rate(k) * 100)}%`).join(", ");
  return [
    `⏳ Ще чекаємо: ~${usd(expected)} net — ${rows.length} ${plural(rows.length, ["оплата", "оплати", "оплат"])} з урахуванням шансу (${chances}):`,
    ...rows.map(detail),
  ];
}

const plural = (n: number, [one, few, many]: string[]) =>
  n % 10 === 1 && n % 100 !== 11 ? one : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20) ? few : many;

function verdict(forecast: number, yesterday: number) {
  if (!yesterday) return "";
  const d = (forecast - yesterday) / yesterday;
  const pct = `${d >= 0 ? "+" : ""}${Math.round(d * 100)}%`;
  if (d >= 0.15) return `📈 ${pct} до вчора — ${pick(["день обіцяє бути жирним", "Apple сьогодні щедрий", "ростемо"])}`;
  if (d <= -0.15) return `📉 ${pct} до вчора — ${pick(["тихий день, не панікуємо", "пауза перед ривком", "вчора було краще, але ще не вечір"])}`;
  return `➡️ ${pct} до вчора — стабільно`;
}

export async function buildForecast() {
  const yesterday = new Date(Date.now() - 86400e3).toLocaleDateString("sv-SE", { timeZone: DAY_TZ });
  const [[rows], [details], [[extra]], [[mkt]], [[prev]], spend] = await Promise.all([
    bq.query({ query: SQL, location: "US" }),
    bq.query({ query: DETAIL_SQL, location: "US" }),
    bq.query({ query: EXTRA_SQL, location: "US" }),
    bq.query({ query: MARKETING_SQL, location: "US" }),
    bq.query({ query: REVIEW_SQL, location: "US" }),
    // Без spend повідомлення все одно має піти.
    adsSpend(yesterday).catch((e) => { logger.error("apple ads spend", e); return null; }),
  ]);
  const byKind = Object.fromEntries((rows as KindRow[]).map((r) => [r.kind, r])) as Record<KindRow["kind"], KindRow>;
  const rate = (k: KindRow["kind"]) =>
    ((byKind[k].hist_ok ?? 0) + PRIOR[k] * PRIOR_WEIGHT) / ((byKind[k].hist_n ?? 0) + PRIOR_WEIGHT);

  const trial = byKind.trial, renewal = byKind.renewal;
  const already = trial.paid_usd + renewal.paid_usd;
  const ahead = trial.paid_ahead_usd + renewal.paid_ahead_usd;
  const expected = trial.pending_usd * rate("trial") + renewal.pending_usd * rate("renewal");
  const forecast = already + expected;
  const pendingRows = (details as DetailRow[]).filter((r) => r.pending);
  const aheadRows = (details as DetailRow[]).filter((r) => !r.pending);
  const today = new Date().toLocaleDateString("uk-UA", { timeZone: DAY_TZ, day: "2-digit", month: "2-digit" });
  const prevReview = review(prev as ReviewRow | undefined);

  // Що запам'ятати, щоб завтра пояснити різницю з фактом.
  const log = {
    date: new Date().toLocaleDateString("sv-SE", { timeZone: DAY_TZ }),
    forecast_usd: round2(forecast),
    already_usd: round2(already),
    pending: pendingRows.map((r) => ({
      original_transaction_id: r.original_transaction_id, due_at: r.due_at.value, kind: r.kind, country: r.country,
      net_usd: r.net_usd, chance: rate(r.kind),
    })),
    created_at: new Date().toISOString(),
  };

  const text = [
    `Шановні оунери, до вашої уваги прогноз по ревеню на сьогодні, <b>${today}</b> (день за UTC, як в Adapty; час оплат — за Києвом):`,
    "",
    `💰 Прогноз: <b>${usd(forecast)} net</b>`,
    verdict(forecast, extra.paid_yesterday_usd),
    "",
    ...paidLines(already, ahead, aheadRows),
    "",
    ...pendingLines(expected, pendingRows, rate),
    "",
    section("🧪 Тріали закінчуються", "сконвертились", trial, rate("trial")),
    "",
    section("🔄 Продовження підписок", "продовжили", renewal, rate("renewal")),
    "",
    `🆕 Тріали сьогодні, ${today} 00:00–${new Date().toISOString().slice(11, 16)} UTC: ${extra.trials_today} ` +
      "(за весь день — у завтрашньому Marketing)",
    `📅 Вчора: ${usd(extra.paid_yesterday_usd)} net, оплат: ${extra.paid_yesterday}`,
    "",
    ...prevReview,
    "",
    marketing(mkt as MarketingRow, spend),
    "",
    pick(["Гарного дня і жирних конверсій.", "Хай chargeback-и обходять нас стороною.", "Тримаємо курс.", "Працюємо далі."]),
  ].filter((l, i, a) => l !== "" || a[i - 1] !== "").join("\n");
  return { text, log };
}

async function sendTelegram(text: string) {
  const res = await fetch(`https://api.telegram.org/bot${botToken.value()}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId.value(), text, parse_mode: "HTML" }),
  });
  if (!res.ok) throw new Error(`telegram ${res.status}: ${await res.text()}`);
}

export const revenueForecast = onSchedule(
  { schedule: "0 9 * * *", timeZone: TZ, region: "us-central1", secrets: [botToken, chatId, adsKey], retryCount: 2 },
  async () => {
    const { text, log } = await buildForecast();
    logger.info("revenue forecast", { text });
    // Без запису завтра просто не буде блоку «прогноз → факт» — повідомлення важливіше.
    await bq.dataset("raw").table("forecast_daily").insert([log]).catch((e) => logger.error("forecast log", e));
    await sendTelegram(text);
  },
);
