#!/bin/sh
set -eu

log() {
  printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

DUMPS_DIR="${BACKUP_DUMPS_DIR:-/backups/db-dumps}"
RETENTION_DAYS="${BACKUP_DUMPS_RETENTION_DAYS:-14}"
TS="$(date -u +'%Y%m%d-%H%M%S')"

ERP_DB_CONTAINER="${ERP_DB_CONTAINER:-infra-erp-db-1}"
ERP_DB_NAME="${ERP_DB_NAME:-erpnext}"
ERP_DB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

NEXTCLOUD_DB_CONTAINER="${NEXTCLOUD_DB_CONTAINER:-nextcloud-db}"
NEXTCLOUD_DB_NAME="${NEXTCLOUD_DB_NAME:-nextcloud}"
NEXTCLOUD_DB_USER="${NEXTCLOUD_DB_USER:-nextcloud}"
NEXTCLOUD_DB_PASSWORD="${NEXTCLOUD_DB_PASSWORD:-}"

mkdir -p "$DUMPS_DIR"

run_dump() {
  container="$1"
  db_name="$2"
  db_user="$3"
  db_password="$4"
  output_file="$5"

  if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
    log "SKIP: container not running: $container"
    return 0
  fi

  if [ -z "$db_password" ]; then
    log "SKIP: missing DB password for $db_name"
    return 0
  fi

  tmp_file="${output_file}.tmp"
  if docker exec -e MYSQL_PWD="$db_password" "$container" sh -c "exec mysqldump -u '$db_user' --single-transaction --quick --lock-tables=false '$db_name'" | gzip -9 > "$tmp_file"; then
    mv "$tmp_file" "$output_file"
    log "OK: wrote dump $output_file"
  else
    rm -f "$tmp_file"
    log "ERROR: failed dump for $db_name from $container"
    return 1
  fi
}

run_dump "$ERP_DB_CONTAINER" "$ERP_DB_NAME" "root" "$ERP_DB_ROOT_PASSWORD" "$DUMPS_DIR/erp-${ERP_DB_NAME}-${TS}.sql.gz"
run_dump "$NEXTCLOUD_DB_CONTAINER" "$NEXTCLOUD_DB_NAME" "$NEXTCLOUD_DB_USER" "$NEXTCLOUD_DB_PASSWORD" "$DUMPS_DIR/nextcloud-${NEXTCLOUD_DB_NAME}-${TS}.sql.gz"

find "$DUMPS_DIR" -type f -name '*.sql.gz' -mtime "+$RETENTION_DAYS" -delete || true
log "Done: DB dump cycle completed"
