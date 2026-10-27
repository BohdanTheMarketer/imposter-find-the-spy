// Ручний запуск лоадерів за довільний діапазон (бекфіл після простою), той самий код, що й у функціях.
//   node lib/backfill.js <asc_sales|asc_subscriber|apple_ads|fx> <start YYYY-MM-DD> [end, за замовч. вчора]
// Доступ до BigQuery — Application Default Credentials (gcloud auth application-default login).
// Ключі — шляхи у ASC_API_KEY_FILE / APPLE_ADS_PRIVATE_KEY_FILE (за замовч. ~/.secrets/imposter/…).
import { readFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import { addDays, dayRange, isoDay, loadAppleAds, loadAscSales, loadAscSubscriber, loadFx } from "./loaders";

const secrets = join(homedir(), ".secrets", "imposter");
const key = (env: string, file: string) => readFileSync(process.env[env] ?? join(secrets, file), "utf8");

async function main() {
  const [what, start, end = addDays(isoDay(new Date()), -1)] = process.argv.slice(2);
  if (!start) throw new Error("usage: backfill.js <asc_sales|asc_subscriber|apple_ads|fx> <start> [end]");
  const days = dayRange(start, end);
  switch (what) {
    case "asc_sales": return loadAscSales(key("ASC_API_KEY_FILE", "AuthKey_69AVX6PM25.p8"), days);
    case "asc_subscriber": return loadAscSubscriber(key("ASC_API_KEY_FILE", "AuthKey_69AVX6PM25.p8"), days);
    case "apple_ads": return loadAppleAds(key("APPLE_ADS_PRIVATE_KEY_FILE", "apple-ads-private.pem"), days);
    case "fx": return loadFx(days);
    default: throw new Error(`unknown loader ${what}`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
