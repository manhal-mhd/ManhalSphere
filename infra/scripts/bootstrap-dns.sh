#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$INFRA_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
	echo "Missing env file: $ENV_FILE"
	exit 1
fi

get_env() {
	local key="$1"
	grep -E "^${key}=" "$ENV_FILE" | tail -n1 | cut -d'=' -f2- | tr -d '\r' | xargs || true
}

BASE_DOMAIN="$(get_env BASE_DOMAIN)"
DNS_API_URL="$(get_env DNS_API_URL)"
DNS_ADMIN_USER="$(get_env DNS_ADMIN_USER)"
DNS_ADMIN_PASSWORD="$(get_env DNS_ADMIN_PASSWORD)"
DNS_RECORD_IP="$(get_env DNS_RECORD_IP)"

if [ -z "$BASE_DOMAIN" ]; then
	echo "BASE_DOMAIN is missing in $ENV_FILE"
	exit 1
fi

DNS_API_URL="${DNS_API_URL:-http://localhost:5380}"
DNS_ADMIN_USER="${DNS_ADMIN_USER:-admin}"
DNS_ADMIN_PASSWORD="${DNS_ADMIN_PASSWORD:-admin}"

if [ -z "$DNS_RECORD_IP" ]; then
	DNS_RECORD_IP="$(curl -fsS https://api.ipify.org 2>/dev/null || true)"
fi
if [ -z "$DNS_RECORD_IP" ]; then
	DNS_RECORD_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi
if [ -z "$DNS_RECORD_IP" ]; then
	echo "Unable to determine DNS_RECORD_IP. Set DNS_RECORD_IP in .env"
	exit 1
fi

api_get() {
	local url="$1"
	shift
	curl -fsS -G "$url" "$@"
}

extract_status() {
	python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))'
}

extract_token() {
	python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))'
}

wait_seconds=60
elapsed=0
until curl -fsS "$DNS_API_URL/" >/dev/null 2>&1; do
	sleep 2
	elapsed=$((elapsed + 2))
	if [ "$elapsed" -ge "$wait_seconds" ]; then
		echo "DNS API did not become reachable within ${wait_seconds}s"
		exit 1
	fi
done

login_resp="$(api_get "$DNS_API_URL/api/user/login" \
	--data-urlencode "user=$DNS_ADMIN_USER" \
	--data-urlencode "pass=$DNS_ADMIN_PASSWORD" \
	--data-urlencode "includeInfo=false" 2>/dev/null || true)"

if [ -z "$login_resp" ]; then
	echo "Failed to login to DNS API at $DNS_API_URL"
	exit 1
fi

status="$(printf '%s' "$login_resp" | extract_status)"
if [ "$status" != "ok" ]; then
	echo "DNS login failed (status: $status). Check DNS_ADMIN_USER/DNS_ADMIN_PASSWORD in .env"
	exit 1
fi

token="$(printf '%s' "$login_resp" | extract_token)"
if [ -z "$token" ]; then
	echo "DNS API token missing in login response"
	exit 1
fi

create_zone_resp="$(api_get "$DNS_API_URL/api/zones/create" \
	--data-urlencode "token=$token" \
	--data-urlencode "zone=$BASE_DOMAIN" \
	--data-urlencode "type=Primary" 2>/dev/null || true)"

create_zone_status="$(printf '%s' "$create_zone_resp" | extract_status 2>/dev/null || echo "")"
if [ "$create_zone_status" = "ok" ]; then
	echo "Created DNS zone: $BASE_DOMAIN"
else
	echo "Zone create skipped or already exists: $BASE_DOMAIN"
fi

records=(
	"$BASE_DOMAIN"
	"portal.$BASE_DOMAIN"
	"erp.$BASE_DOMAIN"
	"mail.$BASE_DOMAIN"
	"dns.$BASE_DOMAIN"
	"files.$BASE_DOMAIN"
	"pw.$BASE_DOMAIN"
	"status.$BASE_DOMAIN"
	"docker.$BASE_DOMAIN"
	"backup.$BASE_DOMAIN"
)

for domain in "${records[@]}"; do
	resp="$(api_get "$DNS_API_URL/api/zones/records/add" \
		--data-urlencode "token=$token" \
		--data-urlencode "domain=$domain" \
		--data-urlencode "zone=$BASE_DOMAIN" \
		--data-urlencode "type=A" \
		--data-urlencode "ttl=300" \
		--data-urlencode "overwrite=true" \
		--data-urlencode "ipAddress=$DNS_RECORD_IP" 2>/dev/null || true)"
	rec_status="$(printf '%s' "$resp" | extract_status 2>/dev/null || echo "")"
	if [ "$rec_status" = "ok" ]; then
		echo "Mapped $domain -> $DNS_RECORD_IP"
	else
		echo "Failed to map $domain (status: ${rec_status:-unknown})"
	fi
done

echo "DNS bootstrap completed for $BASE_DOMAIN"
