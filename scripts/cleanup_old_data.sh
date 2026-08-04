#!/usr/bin/env bash
# Delete captured responses in data/ whose filename date is older than MAX_AGE_DAYS.
#
# Usage: cleanup_old_data.sh
# Optional env: DATA_DIR (default data), MAX_AGE_DAYS (default 30)
#
# Every capture file embeds its date as _YYYY-MM-DD_ in the name, and that date
# is authoritative: checkout resets filesystem mtimes, so file age on disk means
# nothing here. Files without a parseable date are listed and left alone —
# deletion is only ever driven by a date this pipeline wrote itself.

set -euo pipefail

DATA_DIR="${DATA_DIR:-data}"
MAX_AGE_DAYS="${MAX_AGE_DAYS:-30}"

# GNU date (runners) and BSD date (macOS) spell "N days ago" differently.
cutoff=$(date -u -d "${MAX_AGE_DAYS} days ago" +%F 2>/dev/null \
      || date -u -v -"${MAX_AGE_DAYS}"d +%F)
echo "deleting capture files dated before ${cutoff}"

deleted=0
for f in "$DATA_DIR"/*.json; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  if [[ "$name" =~ _([0-9]{4}-[0-9]{2}-[0-9]{2})_ ]]; then
    file_date="${BASH_REMATCH[1]}"
    # Dates are ISO-formatted, so string order is date order.
    if [[ "$file_date" < "$cutoff" ]]; then
      echo "delete ${f} (dated ${file_date})"
      rm "$f"
      deleted=$((deleted + 1))
    fi
  else
    echo "skip   ${f}: no _YYYY-MM-DD_ date in name" >&2
  fi
done

echo "deleted ${deleted} file(s)"
