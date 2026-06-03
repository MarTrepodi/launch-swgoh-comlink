#!/usr/bin/env bash
# Loop over an items-list file and POST each value to swgoh-comlink /data.
#
# Usage: fetch_data_items.sh <items-file>
# Required env: MD_VERSION, DATE_STRING, UNIQUE_ID
# Optional env: COMLINK_URL (default http://localhost:3200), OUT_DIR (default data)

set -uo pipefail

ITEMS_FILE="${1:?items file path required}"
: "${MD_VERSION:?MD_VERSION must be set}"
: "${DATE_STRING:?DATE_STRING must be set}"
: "${UNIQUE_ID:?UNIQUE_ID must be set}"
COMLINK_URL="${COMLINK_URL:-http://localhost:3200}"
OUT_DIR="${OUT_DIR:-data}"

if [ ! -f "$ITEMS_FILE" ]; then
  echo "items file not found: $ITEMS_FILE" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

fail=0
while IFS= read -r line || [ -n "$line" ]; do
  item="${line%%#*}"
  item="$(echo "$item" | tr -d '[:space:]')"
  [ -z "$item" ] && continue

  out="$OUT_DIR/data_response_${DATE_STRING}_${item}_${UNIQUE_ID}.json"
  payload=$(jq -nc --argjson v "$MD_VERSION" --arg i "$item" \
    '{payload:{version:$v,devicePlatform:"Android",includePveUnits:false,items:$i},enums:false}')

  http=$(curl -sS -o "$out" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    "$COMLINK_URL/data")

  if [ "$http" != "200" ]; then
    echo "FAIL item=$item http=$http" >&2
    rm -f "$out"
    fail=1
  else
    echo "OK   item=$item -> $out"
  fi
done < "$ITEMS_FILE"

exit "$fail"
