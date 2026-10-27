// Щоранку в Telegram: прогноз net на сьогодні (дні за Києвом) з mart.renewals_due.
//   прогноз = вже оплачені періоди, що закінчуються сьогодні
//           + ще не оплачені з auto-renew × історична частка оплат (за 30 днів, зі згладжуванням)
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { BigQuery } from "@google-cloud/bigquery";

const TZ = "Europe/Kiev";
const botToken = defineSecret("TELEGRAM_BOT_TOKEN");
const chatId = defineSecret("TELEGRAM_CHAT_ID");

const bq = new BigQuery();

// Поки власних даних мало, частка оплат тягнеться до цих значень (вага — PRIOR_WEIGHT періодів).
const PRIOR = { trial: 0.85, renewal: 0.9 };
const PRIOR_WEIGHT = 10;

const SQL = `
WITH due AS (
  SELECT * FROM mart.renewals_due WHERE DATE(due_at, '${TZ}') = CURRENT_DATE('${TZ}')
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
    WHERE event = 'trial_started' AND DATE(event_at, '${TZ}') = CURRENT_DATE('${TZ}')) AS trials_today,
  (SELECT COUNT(*) FROM mart.renewals_due
    WHERE paid_at IS NOT NULL AND DATE(paid_at, '${TZ}') = DATE_SUB(CURRENT_DATE('${TZ}'), INTERVAL 1 DAY)) AS paid_yesterday,
  (SELECT IFNULL(SUM(paid_net_usd), 0) FROM mart.renewals_due
    WHERE paid_at IS NOT NULL AND DATE(paid_at, '${TZ}') = DATE_SUB(CURRENT_DATE('${TZ}'), INTERVAL 1 DAY)) AS paid_yesterday_usd`;

type KindRow = {
  kind: "trial" | "renewal";
  total: number; paid: number; paid_usd: number;
  pending: number; pending_usd: number;
  billing_retry: number; cancelled: number;
  hist_ok: number | null; hist_n: number | null;
};

const usd = (v: number) => `$${v.toFixed(2)}`;

function section(title: string, r: KindRow, rate: number) {
  const expected = r.pending_usd * rate;
  return [
    `<b>${title}: ${r.total}</b>`,
    `• оплатили: ${r.paid} — ${usd(r.paid_usd)}`,
    `• чекають списання: ${r.pending} → ~${(r.pending * rate).toFixed(1)} / ${usd(expected)} (${Math.round(rate * 100)}%)`,
    `• billing retry: ${r.billing_retry}`,
    `• скасували: ${r.cancelled}`,
  ].join("\n");
}

export async function buildForecast(): Promise<string> {
  const [[rows], [[extra]]] = await Promise.all([
    bq.query({ query: SQL, location: "US" }),
    bq.query({ query: EXTRA_SQL, location: "US" }),
  ]);
  const byKind = Object.fromEntries((rows as KindRow[]).map((r) => [r.kind, r])) as Record<KindRow["kind"], KindRow>;
  const rate = (k: KindRow["kind"]) =>
    ((byKind[k].hist_ok ?? 0) + PRIOR[k] * PRIOR_WEIGHT) / ((byKind[k].hist_n ?? 0) + PRIOR_WEIGHT);

  const trial = byKind.trial, renewal = byKind.renewal;
  const already = trial.paid_usd + renewal.paid_usd;
  const expected = trial.pending_usd * rate("trial") + renewal.pending_usd * rate("renewal");
  const today = new Date().toLocaleDateString("uk-UA", { timeZone: TZ, day: "2-digit", month: "2-digit" });

  return [
    `<b>Imposter · ${today}</b>`,
    `Прогноз net на сьогодні: <b>${usd(already + expected)}</b>`,
    `вже прийшло ${usd(already)} · очікуємо ще ${usd(expected)}`,
    "",
    section("Тріали, що закінчуються сьогодні", trial, rate("trial")),
    "",
    section("Продовження підписок", renewal, rate("renewal")),
    "",
    `Нові тріали з 00:00: ${extra.trials_today}`,
    `Вчора: ${usd(extra.paid_yesterday_usd)} net, оплат: ${extra.paid_yesterday}`,
  ].join("\n");
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
  { schedule: "0 9 * * *", timeZone: TZ, region: "us-central1", secrets: [botToken, chatId], retryCount: 2 },
  async () => {
    const text = await buildForecast();
    logger.info("revenue forecast", { text });
    await sendTelegram(text);
  },
);
