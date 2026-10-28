// Щоденне оновлення raw.adapty_metrics_daily з Adapty Analytics API (як loaders/adapty_metrics_fetch.py).
// Окрема функція: rate limit Adapty, 12 запитів ≈ 5 хв.
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { DAYS, Row, lastDays, replaceDays } from "./refresh";

const adaptyKey = defineSecret("ADAPTY_SECRET_KEY");

const ADAPTY_CHARTS = ["trials_new", "subscriptions_new", "revenue"];
const ADAPTY_SEGS = ["attribution_source", "attribution_campaign", "attribution_adgroup", "attribution_creative"];
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function refreshAdaptyMetrics() {
  const days = lastDays(DAYS);
  const loaded_at = new Date().toISOString();
  const rows: Row[] = [];
  for (const chart_id of ADAPTY_CHARTS) {
    for (const segmentation of ADAPTY_SEGS) {
      let res: Response | undefined;
      // rate limit ~1 запит / 15–20 с
      for (let attempt = 0; attempt < 5; attempt++) {
        res = await fetch("https://api-admin.adapty.io/api/v1/client-api/metrics/analytics/", {
          method: "POST",
          headers: { Authorization: `Api-Key ${adaptyKey.value()}`, "Content-Type": "application/json" },
          body: JSON.stringify({ chart_id, filters: { date: [days[0], days[days.length - 1]] }, period_unit: "day", segmentation_by: segmentation }),
        });
        if (res.status !== 429) break;
        await sleep(30e3);
      }
      if (!res!.ok) throw new Error(`adapty ${chart_id}/${segmentation} ${res!.status}: ${await res!.text()}`);
      // revenue віддає три секції: revenue (gross), proceeds (без комісії Apple), net_revenue (ще й без податку)
      const { data } = await res!.json() as { data: Record<string, { data: { type: string | null; values: { x: string; y: number }[] }[] }> };
      for (const [metric, sec] of Object.entries(data)) {
        for (const s of sec.data) {
          if (s.type === "total") continue;
          for (const p of s.values) {
            if (!p.y) continue;
            rows.push({ date: p.x.slice(0, 10), chart_id, metric, segmentation, segment: s.type || null, value: p.y.toFixed(6), loaded_at });
          }
        }
      }
      await sleep(20e3);
    }
  }
  await replaceDays("raw", "adapty_metrics_daily", "date", days, rows);
}

export const refreshAdapty = onSchedule(
  { schedule: "30 6 * * *", timeZone: "Europe/Kiev", region: "us-central1", secrets: [adaptyKey], timeoutSeconds: 540 },
  refreshAdaptyMetrics,
);
