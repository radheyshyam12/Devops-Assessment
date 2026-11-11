#!/usr/bin/env bash
# Creates a timestamped, compressed (custom format) pg_dump of the local DB.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then set -a; . ./.env; set +a; fi
POSTGRES_USER="${POSTGRES_USER:-hotel}"
POSTGRES_DB="${POSTGRES_DB:-hotel_bookings}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

mkdir -p "$BACKUP_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${BACKUP_DIR}/${POSTGRES_DB}_${TS}.dump"

echo "==> Dumping '${POSTGRES_DB}' to ${OUT}"
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc --no-owner > "${OUT}.tmp"
mv "${OUT}.tmp" "$OUT"

[ -s "$OUT" ] || { echo "ERROR: backup file is empty" >&2; exit 1; }

# Make sure the archive is readable before declaring success.
docker compose exec -T db pg_restore --list < "$OUT" > /dev/null

if command -v sha256sum >/dev/null 2>&1; then sha256sum "$OUT" > "${OUT}.sha256"
else shasum -a 256 "$OUT" > "${OUT}.sha256"; fi

echo "==> Backup OK: ${OUT} ($(wc -c < "$OUT" | tr -d ' ') bytes)"
