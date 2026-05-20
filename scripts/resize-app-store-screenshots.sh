#!/usr/bin/env bash
# Batch-resize PNGs in a folder to App Store screenshot pixel sizes.
#
# Usage:
#   ./scripts/resize-app-store-screenshots.sh <folder> [preset]
#
# Presets (portrait: height x width for sips -z):
#   iphone      — 2778 × 1284  (6.5" / fallback slot; same as 1284×2778 portrait)
#   ipad        — 2732 × 2048  (2048×2732 — 12.9" / still accepted for iPad)
#   ipad13      — 2752 × 2064 (2064×2752 — 13" iPad Pro / Air, listed first on Apple)
#   ipad11      — 2388 × 1668 (1668×2388 — optional 11" slot)
#
# Example:
#   ./scripts/resize-app-store-screenshots.sh ./docs/app-store-raw iphone
#   ./scripts/resize-app-store-screenshots.sh ./docs/app-store-raw/ipad-source ipad13
#
# Output: <folder>/<out-subdir>/Slice-N-<W>x<H>.png for files named "Slice N.png"

set -euo pipefail

SRC="${1:?Usage: $0 <folder-with-png> [iphone|ipad|ipad13|ipad11]}"
PRESET="${2:-iphone}"

case "$PRESET" in
  iphone)
    H=2778
    W=1284
    OUT_SUB="app-store-1284x2778"
    TAG="1284x2778"
    ;;
  ipad)
    H=2732
    W=2048
    OUT_SUB="app-store-2048x2732"
    TAG="2048x2732"
    ;;
  ipad13)
    H=2752
    W=2064
    OUT_SUB="app-store-2064x2752"
    TAG="2064x2752"
    ;;
  ipad11)
    H=2388
    W=1668
    OUT_SUB="app-store-1668x2388"
    TAG="1668x2388"
    ;;
  *)
    echo "Unknown preset: $PRESET (use iphone, ipad, ipad13, ipad11)" >&2
    exit 1
    ;;
esac

OUT="${SRC%/}/${OUT_SUB}"
mkdir -p "${OUT}"

count=0
slice_found=0
for i in $(seq 1 30); do
  f="${SRC}/Slice ${i}.png"
  if [[ -f "$f" ]]; then
    slice_found=1
    out_name="Slice-${i}-${TAG}.png"
    echo "Resizing: Slice ${i}.png → ${out_name}"
    sips -z "${H}" "${W}" "$f" --out "${OUT}/${out_name}"
    count=$((count + 1))
  fi
done

if [[ "$slice_found" -eq 0 ]]; then
  shopt -s nullglob
  for f in "${SRC}"/*.png "${SRC}"/*.PNG; do
    [[ -f "$f" ]] || continue
    bn=$(basename "$f")
    [[ "$bn" == .* ]] && continue
    out_name="${bn%.*}-${TAG}.png"
    echo "Resizing: $bn"
    sips -z "${H}" "${W}" "$f" --out "${OUT}/${out_name}"
    count=$((count + 1))
  done
fi

if [[ "$count" -eq 0 ]]; then
  echo "No .png files found in: ${SRC}" >&2
  exit 1
fi

echo "Done: ${count} file(s) → ${OUT}"
