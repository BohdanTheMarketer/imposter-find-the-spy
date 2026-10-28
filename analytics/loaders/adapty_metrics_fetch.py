import requests, datetime, json, os, sys, time
# Adapty Analytics API: trials / підписки / гроші по днях у розрізі ASA-атрибуції, яку Adapty бере з AdServices.
# attribution_creative = keyword_id, attribution_campaign / attribution_adgroup = id з Apple Ads. Дата — дата події, не інсталу.
start, end, out = sys.argv[1], sys.argv[2], sys.argv[3]
key = os.environ["ADAPTY_SECRET_KEY"]
charts = ["trials_new", "subscriptions_new", "revenue"]
segs = ["attribution_source", "attribution_campaign", "attribution_adgroup", "attribution_creative"]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
rows = 0
with open(out, "w") as f:
    for chart in charts:
        for seg in segs:
            body = {"chart_id": chart, "filters": {"date": [start, end]}, "period_unit": "day", "segmentation_by": seg}
            for attempt in range(5):
                r = requests.post("https://api-admin.adapty.io/api/v1/client-api/metrics/analytics/",
                                  headers={"Authorization": f"Api-Key {key}"}, json=body, timeout=60)
                if r.status_code != 429: break
                time.sleep(30)  # rate limit ~1 запит / 15–20 с
            r.raise_for_status()
            # revenue віддає три секції: revenue (gross), proceeds (без комісії Apple), net_revenue (ще й без податку)
            for metric, sec in r.json()["data"].items():
                for s in sec["data"]:
                    if s["type"] == "total": continue
                    for p in s["values"]:
                        if not p["y"]: continue
                        f.write(json.dumps({"date": p["x"][:10], "chart_id": chart, "metric": metric, "segmentation": seg,
                                            "segment": s["type"] or None, "value": round(p["y"], 6), "loaded_at": now}) + "\n")
                        rows += 1
            print(chart, seg, "ok")
            time.sleep(20)
print("rows:", rows)
