import csv, glob, json, sys, datetime
src, out = sys.argv[1], sys.argv[2]
now = datetime.datetime.utcnow().isoformat() + "Z"
def v(x): x = (x or "").strip(); return x or None
def d(x): m, dd, y = x.strip().split("/"); return f"{y}-{m}-{dd}"   # Apple пише MM/DD/YYYY
n = 0
with open(out, "w") as f:
    for path in sorted(glob.glob(f"{src}/*.tsv")):
        for r in csv.DictReader(open(path), delimiter="\t"):
            f.write(json.dumps({
                "event_date": d(r["Begin Date"]), "product_type": v(r["Product Type Identifier"]),
                "sku": v(r["SKU"]), "title": v(r["Title"]), "apple_identifier": v(r["Apple Identifier"]),
                "parent_identifier": v(r["Parent Identifier"]), "version": v(r["Version"]),
                "country": v(r["Country Code"]), "device": v(r["Device"]),
                "units": int(float(v(r["Units"]) or 0)), "customer_price": v(r["Customer Price"]),
                "customer_currency": v(r["Customer Currency"]), "developer_proceeds": v(r["Developer Proceeds"]),
                "proceeds_currency": v(r["Currency of Proceeds"]), "promo_code": v(r["Promo Code"]),
                "subscription": v(r["Subscription"]), "period": v(r["Period"]),
                "order_type": v(r["Order Type"]), "loaded_at": now}) + "\n")
            n += 1
print("rows:", n)
