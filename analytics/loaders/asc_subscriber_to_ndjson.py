import csv, glob, json, sys, datetime
src, out = sys.argv[1], sys.argv[2]
now = datetime.datetime.utcnow().isoformat() + "Z"
def v(x): x = (x or "").strip(); return x or None
n = 0
with open(out, "w") as f:
    for path in sorted(glob.glob(f"{src}/*.tsv")):
        for r in csv.DictReader(open(path), delimiter="\t"):
            f.write(json.dumps({
                "event_date": v(r["Event Date"]), "subscriber_id": v(r["Subscriber ID"]),
                "subscription_name": v(r["Subscription Name"]), "subscription_apple_id": v(r["Subscription Apple ID"]),
                "standard_duration": v(r["Standard Subscription Duration"]), "offer_type": v(r["Subscription Offer Type"]),
                "offer_duration": v(r["Subscription Offer Duration"]), "customer_price": v(r["Customer Price"]),
                "customer_currency": v(r["Customer Currency"]), "developer_proceeds": v(r["Developer Proceeds"]),
                "proceeds_currency": v(r["Proceeds Currency"]), "proceeds_reason": v(r["Proceeds Reason"]),
                "device": v(r["Device"]), "country": v(r["Country"]), "refund": v(r["Refund"]),
                "purchase_date": v(r["Purchase Date"]), "units": int(v(r["Units"]) or 0), "loaded_at": now}) + "\n")
            n += 1
print("rows:", n)
