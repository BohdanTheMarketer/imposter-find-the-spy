# Loaders (ручний бекфіл; основа для майбутніх Cloud Functions)

Залежності: `python3 -m venv .venv && .venv/bin/pip install pyjwt cryptography requests`.
Ключі — `~/.secrets/imposter/` (не в репо).

```
# SUBSCRIBER-звіти App Store Connect за останні 365 днів → TSV по днях
.venv/bin/python3 asc_subscriber_fetch.py /tmp/asc_subscriber
python3 asc_subscriber_to_ndjson.py /tmp/asc_subscriber /tmp/asc_subscriber.ndjson
bq load --replace --source_format=NEWLINE_DELIMITED_JSON raw.asc_subscriber_daily /tmp/asc_subscriber.ndjson

# SALES SUMMARY (installs: 1F first-time, 3F redownload) за останні 365 днів → raw.asc_sales_daily
.venv/bin/python3 asc_sales_fetch.py /tmp/asc_sales
python3 asc_sales_to_ndjson.py /tmp/asc_sales /tmp/asc_sales.ndjson
bq load --replace --source_format=NEWLINE_DELIMITED_JSON raw.asc_sales_daily /tmp/asc_sales.ndjson

# Курси USD з дати
.venv/bin/python3 fx_fetch.py 2026-05-01 /tmp/fx.ndjson
bq load --replace --source_format=NEWLINE_DELIMITED_JSON ref.fx_daily /tmp/fx.ndjson
```

# Apple Ads spend (org 21082690, USD). Ключ — ~/.secrets/imposter/apple-ads-private.pem
```
.venv/bin/python3 apple_ads_check.py                                   # токен + список org
.venv/bin/python3 apple_ads_keywords_fetch.py 2026-05-01 /tmp/kw.ndjson    # keyword × країна × день
# Search Tab і Search Match не мають keyword: різниця ad group − keywords → keyword_id = 0
.venv/bin/python3 apple_ads_residual_fetch.py 2026-05-01 /tmp/kw.ndjson /tmp/res.ndjson
cat /tmp/kw.ndjson /tmp/res.ndjson > /tmp/ads.ndjson
bq load --replace --source_format=NEWLINE_DELIMITED_JSON raw.apple_ads_keyword_daily /tmp/ads.ndjson
```
Звірка: SUM(spend) має дорівнювати spend кампаній (скрипт друкує обидві суми).
