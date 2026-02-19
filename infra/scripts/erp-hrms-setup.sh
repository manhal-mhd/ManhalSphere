#!/usr/bin/env bash
set -euo pipefail

SITE="${ERP_SITE_NAME:-erp.octalearn.sd}"
DB_NAME="${ERP_DB_NAME:-erpnext}"
DB_USER="${ERP_DB_USER:-erpnext}"
DB_ROOT_PASS="${MARIADB_ROOT_PASSWORD:-change_me_root}"
ADMIN_PASS="${ERP_ADMIN_PASSWORD:-admin}"
SOCKETIO_PORT="${SOCKETIO_PORT:-9000}"

cd /home/frappe/frappe-bench

echo "Waiting for MariaDB at ${DB_HOST:-erp-db}:${DB_PORT:-3306}..."
for attempt in $(seq 1 60); do
  if mysqladmin ping -h "${DB_HOST:-erp-db}" -P "${DB_PORT:-3306}" -uroot -p"$DB_ROOT_PASS" --silent >/dev/null 2>&1; then
    echo "MariaDB is ready."
    break
  fi

  if [ "$attempt" -eq 60 ]; then
    echo "ERROR: MariaDB did not become ready in time" >&2
    exit 1
  fi

  sleep 2
done

# If HRMS isn't cloned yet but is listed, remove it to avoid import errors
if [ ! -d apps/hrms ] && [ -f sites/apps.txt ]; then
  sed -i '/^hrms$/d' sites/apps.txt || true
fi

if [ -f apps.txt ]; then
  sed -i '/^erpnexthrms$/d' apps.txt || true
fi

if [ -f sites/apps.txt ]; then
  sed -i '/^erpnexthrms$/d' sites/apps.txt || true
fi

# Also remove hrms from apps.json if present
if [ ! -d apps/hrms ] && [ -f sites/apps.json ]; then
  python - <<'PY'
import json
from pathlib import Path
p = Path('sites')/ 'apps.json'
data = json.loads(p.read_text())
if 'hrms' in data:
    del data['hrms']
    p.write_text(json.dumps(data, indent=4))
PY
fi

bench set-config -g db_host erp-db
bench set-config -gp db_port 3306
bench set-config -g redis_cache "redis://erp-redis-cache:6379"
bench set-config -g redis_queue "redis://erp-redis-queue:6379"
bench set-config -g redis_socketio "redis://erp-redis-queue:6379"
bench set-config -gp socketio_port "$SOCKETIO_PORT"

if [ ! -f "sites/$SITE/site_config.json" ]; then
  bench new-site "$SITE" \
    --mariadb-root-username root \
    --mariadb-root-password "$DB_ROOT_PASS" \
    --db-name "$DB_NAME" \
    --admin-password "$ADMIN_PASS" \
    --install-app erpnext || true
fi

DB_PASSWORD=$(python -c 'import json, os; site=os.environ.get("ERP_SITE_NAME","erp.octalearn.sd"); path=os.path.join("sites", site, "site_config.json"); print(json.load(open(path))["db_password"])')

mysql -h erp-db -uroot -p"$DB_ROOT_PASS" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD'; ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;"

if [ ! -d apps/hrms ]; then
  bench get-app https://github.com/frappe/hrms --branch version-15
fi

if ! grep -qx 'hrms' sites/apps.txt; then
  echo 'hrms' >> sites/apps.txt
fi

if [ -f apps.txt ] && ! grep -qx 'hrms' apps.txt; then
  echo 'hrms' >> apps.txt
fi

# Verify hrms app directory exists before install
if [ ! -d apps/hrms ]; then
  echo "ERROR: hrms app clone not found under apps/hrms" >&2
  exit 1
fi

# Ensure hrms is importable in this container's virtualenv
if [ -d env ]; then
  # shellcheck disable=SC1091
  . env/bin/activate
  pip install -U pip
  pip install -e apps/hrms
fi

bench --site "$SITE" install-app hrms || true
bench --site "$SITE" migrate
