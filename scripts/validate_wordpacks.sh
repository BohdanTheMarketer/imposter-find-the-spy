#!/usr/bin/env bash
# Validates all word pack JSON files under ImposterGame/Resources/WordPacks/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKS_ROOT="${ROOT}/ImposterGame/Resources/WordPacks"
REQUIRED_LOCALES=(en pt-BR fr es-MX tr)
REQUIRED_PACKS=(
  party_time world_cup food celebrities hobbies family school spicy sports
  travel work_life movies shopping tech superpowers music places
)

errors=0

for locale in "${REQUIRED_LOCALES[@]}"; do
  dir="${PACKS_ROOT}/${locale}"
  if [[ ! -d "$dir" ]]; then
    echo "ERROR: missing locale folder ${dir}"
    errors=$((errors + 1))
    continue
  fi
  for pack in "${REQUIRED_PACKS[@]}"; do
    file="${dir}/${pack}.json"
    if [[ ! -f "$file" ]]; then
      echo "ERROR: missing ${locale}/${pack}.json"
      errors=$((errors + 1))
      continue
    fi
    if ! python3 - "$file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    d = json.load(f)
required = ["category", "icon", "description", "words", "imposterHints"]
for k in required:
    if k not in d:
        raise SystemExit(f"missing key: {k}")
if not isinstance(d["words"], list) or not d["words"]:
    raise SystemExit("words must be non-empty list")
hints = d.get("imposterHints") or []
if len(hints) != len(d["words"]):
    raise SystemExit(f"imposterHints count {len(hints)} != words {len(d['words'])}")
if any(not str(w).strip() for w in d["words"]):
    raise SystemExit("empty word entry")
PY
    then
      echo "ERROR: invalid schema ${locale}/${pack}.json"
      errors=$((errors + 1))
    fi
  done
done

# Lint .strings if plutil available
if command -v plutil >/dev/null 2>&1; then
  for lproj in "${ROOT}/ImposterGame"/*.lproj; do
    strings="${lproj}/Localizable.strings"
    if [[ -f "$strings" ]]; then
      plutil -lint "$strings" >/dev/null || { echo "ERROR: plutil failed $strings"; errors=$((errors + 1)); }
    fi
    dict="${lproj}/Localizable.stringsdict"
    if [[ -f "$dict" ]]; then
      plutil -lint "$dict" >/dev/null || { echo "ERROR: plutil failed $dict"; errors=$((errors + 1)); }
    fi
  done
fi

if [[ $errors -gt 0 ]]; then
  echo "validate_wordpacks: FAILED ($errors errors)"
  exit 1
fi
echo "validate_wordpacks: OK (${#REQUIRED_LOCALES[@]} locales × ${#REQUIRED_PACKS[@]} packs)"
