#!/bin/sh
set -eu

INTERVAL_HOURS="${BACKUP_DUMP_INTERVAL_HOURS:-24}"
if [ "$INTERVAL_HOURS" -le 0 ] 2>/dev/null; then
  INTERVAL_HOURS=24
fi
INTERVAL_SECONDS=$((INTERVAL_HOURS * 3600))

echo "[backup-db-dumps] interval: ${INTERVAL_HOURS}h"

while true; do
  /bin/sh /scripts/backup-db-dumps.sh || true
  sleep "$INTERVAL_SECONDS"
done
