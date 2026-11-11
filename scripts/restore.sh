#!/usr/bin/env bash
# Restores a backup into a FRESH database (default: hotel_restore) and verifies it.
# Usage: ./scripts/restore.sh [backup_file] [target_db]
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then set -a; . ./.env; set +a; fi
POSTGRES_USER="${POSTGRES_USER:-hotel}"
SOURCE_DB="${POSTGRES_DB:-hotel_bookings}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

FILE="${1:-$(ls -1t "$BACKUP_DIR"/*.dump 2>/dev/null | head -n1 || true)}"
TARGET_DB="${2:-hotel_restore}"

[ -n "$FILE" ] && [ -f "$FILE" ] || { echo "ERROR: no backup found. Run ./scripts/backup.sh first." >&2; exit 1; }
[ "$TARGET_DB" != "$SOURCE_DB" ] || { echo "ERROR: refusing to restore over the source database '${SOURCE_DB}'." >&2; exit 1; }

pg()  { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres "$@"; }
q()   { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$1" -Atc "$2"; }

echo "==> Recreating fresh database '${TARGET_DB}'"
pg -c "DROP DATABASE IF EXISTS \"${TARGET_DB}\" WITH (FORCE);"
pg -c "CREATE DATABASE \"${TARGET_DB}\";"

echo "==> Restoring ${FILE}"
docker compose exec -T db pg_restore -U "$POSTGRES_USER" -d "$TARGET_DB" --no-owner --exit-on-error < "$FILE"

echo "==> Verifying"
BOOK_SQL="SELECT count(*) || ',' || COALESCE(sum(amount),0) FROM hotel_bookings"
EVT_SQL="SELECT count(*) FROM booking_events"
R_BOOK="$(q "$TARGET_DB" "$BOOK_SQL")"
R_EVT="$(q "$TARGET_DB" "$EVT_SQL")"
R_IDX="$(q "$TARGET_DB" "SELECT count(*) FROM pg_indexes WHERE indexname IN ('idx_hotel_bookings_city_created_at_cov','idx_booking_events_booking_id')")"

echo "   restored hotel_bookings (count,sum): ${R_BOOK}"
echo "   restored booking_events (count)    : ${R_EVT}"
echo "   restored custom indexes (expect 2) : ${R_IDX}"

[ "$R_IDX" = "2" ] || { echo "FAIL: indexes missing after restore" >&2; exit 1; }

# Compare with the live source DB when it is available.
if [ "$(pg -Atc "SELECT 1 FROM pg_database WHERE datname='${SOURCE_DB}'")" = "1" ]; then
  S_BOOK="$(q "$SOURCE_DB" "$BOOK_SQL")"
  S_EVT="$(q "$SOURCE_DB" "$EVT_SQL")"
  echo "   source   hotel_bookings (count,sum): ${S_BOOK}"
  echo "   source   booking_events (count)    : ${S_EVT}"
  if [ "$S_BOOK" != "$R_BOOK" ] || [ "$S_EVT" != "$R_EVT" ]; then
    echo "FAIL: restored data does not match the source" >&2; exit 1
  fi
fi

echo "==> RESTORE VERIFIED: '${TARGET_DB}' matches the backup."
