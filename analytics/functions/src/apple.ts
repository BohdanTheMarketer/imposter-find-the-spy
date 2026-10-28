// JWT і токени для API Apple (App Store Connect, Apple Ads) — ES256 без сторонніх бібліотек.
import { createPrivateKey, sign } from "node:crypto";

// Ідентифікатори — не секрети; приватні ключі лежать у Secret Manager.
export const ASC = { issuer: "6d7538b8-bc63-428c-8ec2-42cb6c43caf9", kid: "69AVX6PM25", vendor: "94139603" };
// Org у USD, таймзона org — Europe/Kiev; звіти беремо з timeZone UTC — дні як в Adapty і BigQuery.
export const ADS = {
  client: "SEARCHADS.9a079a92-2a52-480c-bb86-272371b0e497",
  kid: "49d9ffcc-ecc5-428d-9616-d10d3b4bfa3f",
  org: 21082690,
  api: "https://api.searchads.apple.com/api/v5",
};

const b64url = (v: string | Buffer) => Buffer.from(v).toString("base64url");

export function es256Jwt(header: object, payload: object, pem: string) {
  const data = `${b64url(JSON.stringify({ alg: "ES256", ...header }))}.${b64url(JSON.stringify(payload))}`;
  const sig = sign("sha256", Buffer.from(data), { key: createPrivateKey(pem), dsaEncoding: "ieee-p1363" });
  return `${data}.${b64url(sig)}`;
}

export function ascToken(pem: string) {
  const now = Math.floor(Date.now() / 1000);
  return es256Jwt({ kid: ASC.kid, typ: "JWT" }, { iss: ASC.issuer, iat: now, exp: now + 1100, aud: "appstoreconnect-v1" }, pem);
}

// Заголовки для Apple Ads API (OAuth client_credentials з client_secret = JWT).
export async function adsHeaders(pem: string) {
  const now = Math.floor(Date.now() / 1000);
  const secret = es256Jwt(
    { kid: ADS.kid },
    { sub: ADS.client, iss: ADS.client, iat: now, exp: now + 3600, aud: "https://appleid.apple.com" },
    pem,
  );
  const res = await fetch("https://appleid.apple.com/auth/oauth2/token", {
    method: "POST",
    body: new URLSearchParams({ grant_type: "client_credentials", client_id: ADS.client, client_secret: secret, scope: "searchadsorg" }),
  });
  if (!res.ok) throw new Error(`apple ads token ${res.status}: ${await res.text()}`);
  const { access_token } = await res.json() as { access_token: string };
  return { Authorization: `Bearer ${access_token}`, "X-AP-Context": `orgId=${ADS.org}`, "Content-Type": "application/json" };
}

export type AdsMetrics = {
  date: string; impressions?: number; taps?: number; tapInstalls?: number; viewInstalls?: number;
  localSpend?: { amount: string; currency: string };
};
export type AdsRow = { metadata: Record<string, any>; granularity?: AdsMetrics[] };

// Звіт Apple Ads по днях з пагінацією. path: "campaigns", "campaigns/{id}/keywords", "campaigns/{id}/adgroups".
// Дні — UTC.
export async function adsReport(headers: Record<string, string>, path: string, from: string, to: string, groupBy: string[] = []) {
  const rows: AdsRow[] = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await fetch(`${ADS.api}/reports/${path}`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        startTime: from, endTime: to, granularity: "DAILY", timeZone: "UTC", groupBy,
        selector: { orderBy: [{ field: "localSpend", sortOrder: "DESCENDING" }], pagination: { offset, limit: 1000 } },
        returnRecordsWithNoMetrics: false, returnRowTotals: false, returnGrandTotals: false,
      }),
    });
    if (!res.ok) throw new Error(`apple ads ${path} ${res.status}: ${await res.text()}`);
    const json = await res.json() as { data: { reportingDataResponse: { row?: AdsRow[] } }; pagination?: { totalResults: number } };
    rows.push(...(json.data.reportingDataResponse.row ?? []));
    if (offset + 1000 >= (json.pagination?.totalResults ?? 0)) return rows;
  }
}
