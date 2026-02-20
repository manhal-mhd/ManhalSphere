#!/usr/bin/env bash
set -euo pipefail

# deploy-portal.sh
# Usage: ./deploy-portal.sh [base-domain]
# If no argument is provided the script will try to read BASE_DOMAIN from .env

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PORTAL_DIR="$HERE/portal"
TEMPLATE="$PORTAL_DIR/index.html.template"
OUT="$PORTAL_DIR/index.html"
COMPOSE_FILE="$HERE/docker-compose.yml"

get_from_env(){
  local key=$1
  [ -f "$HERE/.env" ] || return 1
  grep -E "^${key}=" "$HERE/.env" | sed -E "s/^${key}=(.*)/\1/" || return 1
}

if [ "$#" -ge 1 ]; then
  BASE_DOMAIN="$1"
else
  BASE_DOMAIN=$(get_from_env BASE_DOMAIN || true)
  if [ -z "$BASE_DOMAIN" ]; then
    read -rp "Enter base domain (e.g. example.com): " BASE_DOMAIN
  fi
fi

echo "Deploying portal with base domain: $BASE_DOMAIN"

if [ ! -f "$TEMPLATE" ]; then
  echo "Template $TEMPLATE not found" >&2
  exit 1
fi

# Replace placeholder and write output to a temp file
tmpfile=$(mktemp --tmpdir "index.html.XXXXXX")
sed "s/{{BASE_DOMAIN}}/${BASE_DOMAIN}/g" "$TEMPLATE" > "$tmpfile"

# Ensure we atomically install the file into place with correct permissions
if mv "$tmpfile" "$OUT" 2>/dev/null; then
  echo "Updated $OUT"
else
  echo "Installing $OUT with sudo (insufficient permissions)"
  sudo mv "$tmpfile" "$OUT"
  echo "Updated $OUT (via sudo)"
fi

# Ensure correct ownership and permissions so nginx can read the file
sudo chown --reference="$PORTAL_DIR" "$OUT" 2>/dev/null || true
sudo chmod 644 "$OUT" 2>/dev/null || true

# Restart portal service
cd "$HERE"
echo "Restarting portal service..."
sudo docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate portal

# Verify the file is visible inside the container
sleep 1
if sudo docker compose -f "$COMPOSE_FILE" exec -T portal grep -q "$BASE_DOMAIN" /usr/share/nginx/html/index.html; then
  echo "Verification: portal container serves the updated index.html (contains $BASE_DOMAIN)"
else
  echo "Warning: verification failed — the container's index.html does not contain $BASE_DOMAIN" >&2
  echo "You can inspect /usr/share/nginx/html/index.html inside the portal container." >&2
  exit 2
fi

echo "Portal deployed successfully."
