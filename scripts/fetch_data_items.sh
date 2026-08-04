#!/usr/bin/env bash
# Loop over an items-list file and POST each value to swgoh-comlink /data.
#
# Usage: fetch_data_items.sh <items-file>
# Required env: MD_VERSION, DATE_STRING, UNIQUE_ID
# Optional env: COMLINK_URL (default http://localhost:3200), OUT_DIR (default data),
#               FILE_PREFIX (default data_response), MAX_ATTEMPTS (default 4),
#               RETRY_BASE_DELAY (default 15 seconds, doubled after each attempt)

set -uo pipefail

ITEMS_FILE="${1:?items file path required}"
: "${MD_VERSION:?MD_VERSION must be set}"
: "${DATE_STRING:?DATE_STRING must be set}"
: "${UNIQUE_ID:?UNIQUE_ID must be set}"
COMLINK_URL="${COMLINK_URL:-http://localhost:3200}"
OUT_DIR="${OUT_DIR:-data}"
FILE_PREFIX="${FILE_PREFIX:-data_response}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-4}"
RETRY_BASE_DELAY="${RETRY_BASE_DELAY:-15}"

if [ ! -f "$ITEMS_FILE" ]; then
  echo "items file not found: $ITEMS_FILE" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

# Classifies a /data response as "<cause><TAB><detail>".
#
# `ok` means the body carries usable game data. The others name a distinct
# failure mode:
#   upstream_no_response  comlink reached EA and got no usable data back. It
#                         reports this as a {"code":N,"message":"..."} envelope —
#                         valid JSON carrying no game data, which a status check
#                         alone would not catch. Treat the message text as "the
#                         upstream call returned nothing usable" and nothing more
#                         specific (see docs/adr/0001).
#   http_error            non-200 without a comlink envelope.
#   empty_collections     200 and well-formed, but every collection is empty.
#   invalid_json          body is not a JSON object.
classify_response() {
  jq -r --arg http "$2" '
    if type != "object" then "invalid_json\tresponse is not a JSON object"
    elif has("message") then "upstream_no_response\tcomlink says: " + (.message | tostring)
    elif $http != "200" then "http_error\tunexpected status " + $http
    elif ([to_entries[] | select((.value | type) == "array" and (.value | length) > 0)] | length) == 0
      then "empty_collections\tresponse contains no populated collections"
    else "ok\t"
    end' "$1" 2>/dev/null || printf 'invalid_json\tresponse is not valid JSON\n'
}

fail=0
while IFS= read -r line || [ -n "$line" ]; do
  item="${line%%#*}"
  item="$(echo "$item" | tr -d '[:space:]')"
  [ -z "$item" ] && continue

  out="$OUT_DIR/${FILE_PREFIX}_${DATE_STRING}_${item}_${UNIQUE_ID}.json"
  payload=$(jq -nc --argjson v "$MD_VERSION" --arg i "$item" \
    '{payload:{version:$v,devicePlatform:"Android",includePveUnits:false,items:$i},enums:false}')

  attempt=1
  delay="$RETRY_BASE_DELAY"
  ok=0
  cause="http_error"
  detail="no attempt completed"
  while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    http=$(curl -sS -o "$out" -w '%{http_code}' -X POST \
      --connect-timeout 20 --max-time 600 \
      -H 'Content-Type: application/json' \
      -d "$payload" \
      "$COMLINK_URL/data")

    verdict="$(classify_response "$out" "$http")"
    cause="${verdict%%$'\t'*}"
    detail="${verdict#*$'\t'}"

    if [ "$cause" = "ok" ]; then
      ok=1
      break
    fi

    echo "  attempt $attempt/$MAX_ATTEMPTS failed: item=$item http=$http cause=$cause ${detail}" >&2
    rm -f "$out"

    attempt=$((attempt + 1))
    if [ "$attempt" -le "$MAX_ATTEMPTS" ]; then
      echo "  retrying in ${delay}s..." >&2
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done

  if [ "$ok" = 1 ]; then
    echo "OK   item=$item -> $out"
  else
    echo "FAIL item=$item after $MAX_ATTEMPTS attempts (cause=$cause)" >&2
    fail=1
  fi
done < "$ITEMS_FILE"

exit "$fail"
