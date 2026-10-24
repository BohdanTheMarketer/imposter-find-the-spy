import requests, datetime, json, sys, warnings
from concurrent.futures import ThreadPoolExecutor
warnings.filterwarnings("ignore")
start, out = datetime.date.fromisoformat(sys.argv[1]), sys.argv[2]
days = [(start + datetime.timedelta(days=i)).isoformat() for i in range((datetime.date.today() - start).days)]
def get(d):
    for url in (f"https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@{d}/v1/currencies/usd.json",
                f"https://{d}.currency-api.pages.dev/v1/currencies/usd.json"):
        try:
            r = requests.get(url, timeout=30)
            if r.ok: return d, r.json()["usd"]
        except Exception: pass
    return d, None
rows, missing = 0, []
with open(out, "w") as f:
    for d, rates in ThreadPoolExecutor(8).map(get, days):
        if not rates: missing.append(d); continue
        for cur, per_usd in rates.items():
            if len(cur) == 3 and per_usd:
                f.write(json.dumps({"date": d, "currency": cur.upper(), "usd_per_unit": f"{1/per_usd:.9f}"}) + "\n"); rows += 1
print("days:", len(days) - len(missing), "rows:", rows, "missing:", missing[:10])
