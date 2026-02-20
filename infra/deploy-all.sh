#!/usr/bin/env bash
set -euo pipefail

# Simple deployment script to start all core ManhalSphere services over HTTP only.
# Run from the infra directory:  sudo bash deploy-all.sh  OR  bash deploy-all.sh (it will use sudo internally).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"
BASE_DOMAIN=""
ERP_WAIT_TIMEOUT="${ERP_WAIT_TIMEOUT:-900}"
ERP_WAIT_INTERVAL="${ERP_WAIT_INTERVAL:-5}"

init_colors() {
	if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
		C_RESET='\033[0m'
		C_BOLD='\033[1m'
		C_GREEN='\033[32m'
		C_YELLOW='\033[33m'
		C_BLUE='\033[34m'
		C_CYAN='\033[36m'
		C_RED='\033[31m'
	else
		C_RESET=''
		C_BOLD=''
		C_GREEN=''
		C_YELLOW=''
		C_BLUE=''
		C_CYAN=''
		C_RED=''
	fi
}

print_header() {
	echo
	echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
	echo -e "${C_BOLD}${C_CYAN}  ManhalSphere Deployment${C_RESET}"
	echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
}

print_step() {
	echo
	echo -e "${C_BOLD}${C_BLUE}$1${C_RESET}"
}

print_ok() {
	echo -e "${C_GREEN}✔${C_RESET} $1"
}

print_warn() {
	echo -e "${C_YELLOW}⚠${C_RESET} $1"
}

print_fail() {
	echo -e "${C_RED}✖${C_RESET} $1"
}

load_base_domain() {
	if [ -f "$ENV_FILE" ]; then
		BASE_DOMAIN="$(grep -E '^BASE_DOMAIN=' "$ENV_FILE" | tail -n1 | cut -d'=' -f2- | tr -d '\r' | xargs || true)"
	fi
}

render_portal_config() {
	print_step "[Init] Rendering portal config from BASE_DOMAIN..."
	if [ -x "scripts/render-portal-config.sh" ]; then
		if bash scripts/render-portal-config.sh; then
			print_ok "[Init] Portal config rendered"
		else
			print_fail "[Init] Portal config render failed"
			exit 1
		fi
	else
		print_warn "scripts/render-portal-config.sh not executable; attempting to run via bash"
		if bash scripts/render-portal-config.sh; then
			print_ok "[Init] Portal config rendered"
		else
			print_fail "[Init] Portal config render failed"
			exit 1
		fi
	fi
}

bootstrap_dns_records() {
	print_step "[Init] Bootstrapping DNS zone and subdomain records..."
	if bash scripts/bootstrap-dns.sh; then
		print_ok "[Init] DNS records synchronized"
	else
		print_warn "[Init] DNS bootstrap failed (continuing deployment)."
		print_warn "Check DNS admin credentials in .env: DNS_ADMIN_USER / DNS_ADMIN_PASSWORD"
	fi
}

wait_for_erp_ready() {
	if [ -z "$BASE_DOMAIN" ]; then
		print_warn "BASE_DOMAIN not found in .env; skipping ERP readiness wait."
		return 0
	fi

	local erp_url="https://erp.${BASE_DOMAIN}/"
	local elapsed=0
	local code=""

	print_step "[ERP] Waiting for ERP endpoint to become healthy..."
	print_warn "Warm-up may take several minutes after reset/redeploy."

	while [ "$elapsed" -lt "$ERP_WAIT_TIMEOUT" ]; do
		code="$(curl -kLsS -o /dev/null -w '%{http_code}' "$erp_url" 2>/dev/null || true)"
		if echo "$code" | grep -Eq '^(200|301|302)$'; then
			print_ok "ERP is ready (HTTP $code) after ${elapsed}s"
			return 0
		fi

		sleep "$ERP_WAIT_INTERVAL"
		elapsed=$((elapsed + ERP_WAIT_INTERVAL))
		if [ $((elapsed % 30)) -eq 0 ]; then
			print_warn "ERP still warming up... (${elapsed}s elapsed, last HTTP ${code:-n/a})"
		fi
	done

	print_fail "ERP did not become ready within ${ERP_WAIT_TIMEOUT}s (last HTTP ${code:-n/a})."
	print_warn "Check: sudo docker logs infra-erp-app-1"
	return 1
}

compose_cmd() {
	if docker compose version >/dev/null 2>&1; then
		sudo docker compose "$@"
	else
		sudo docker-compose "$@"
	fi
}

run_stack() {
	local label="$1"
	shift
	print_step "$label"
	if compose_cmd "$@"; then
		print_ok "$label completed"
	else
		print_fail "$label failed"
		exit 1
	fi
}

init_colors
load_base_domain
print_header
render_portal_config

run_stack "[1/6] Starting core infrastructure stack (proxy, portal, dns, backup, monitoring, wireguard)..." \
	-f docker-compose.yml up -d

deploy_portal_site() {
	if [ -z "$BASE_DOMAIN" ]; then
		print_warn "BASE_DOMAIN not set; skipping portal HTML render/deploy."
		return 0
	fi

	print_step "[Init] Deploying portal static site (index.html)..."
	if [ -x "scripts/deploy-portal.sh" ]; then
		if bash scripts/deploy-portal.sh "$BASE_DOMAIN"; then
			print_ok "Portal deployed"
		else
			print_warn "Portal deploy script failed"
		fi
	else
		print_warn "scripts/deploy-portal.sh not executable; attempting to run via bash"
		if bash scripts/deploy-portal.sh "$BASE_DOMAIN"; then
			print_ok "Portal deployed"
		else
			print_warn "Portal deploy script failed"
		fi
	fi
}

bootstrap_dns_records

deploy_portal_site

run_stack "[2/6] Building and starting ERP core services..." \
	-f docker-compose.erpnext-hrms.yml up -d --build erp-db erp-redis-cache erp-redis-queue erp-app

print_step "[ERP] Running ERP+HRMS setup/migrations..."
if compose_cmd -f docker-compose.erpnext-hrms.yml run --rm erp-hrms-setup; then
	print_ok "[ERP] Setup/migrations completed"
else
	print_fail "[ERP] Setup/migrations failed"
	exit 1
fi

run_stack "[ERP] Starting ERP web (nginx)..." \
	-f docker-compose.erpnext-hrms.yml up -d erp-nginx

wait_for_erp_ready

run_stack "[3/6] Starting Nextcloud stack..." \
	-f docker-compose.nextcloud.yml up -d

run_stack "[4/6] Starting Vaultwarden stack..." \
	-f docker-compose.vaultwarden.yml up -d

print_step "[5/6] Starting Mailu stack..."
if [ -f "mailu.env" ]; then
	if compose_cmd -f docker-compose.mail.yml up -d; then
		print_ok "[5/6] Mailu stack completed"
	else
		print_fail "[5/6] Mailu stack failed"
		exit 1
	fi
else
	print_warn "mailu.env not found. Skipping Mailu deployment."
	print_warn "To set up: cp mailu.env.example mailu.env and update DOMAIN, HOSTNAMES, SECRET_KEY, TLS settings."
fi

echo
print_ok "All requested services are starting."
echo -e "${C_BOLD}Next:${C_RESET} Use 'sudo docker ps' to verify."
