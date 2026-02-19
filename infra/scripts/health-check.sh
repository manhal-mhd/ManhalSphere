#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$INFRA_DIR/.env"

init_colors() {
  if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_CYAN='\033[36m'
  else
    C_RESET=''
    C_BOLD=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_CYAN=''
  fi
}

print_header() {
  echo
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}  Office-in-a-Box Health Check${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
}

print_section() {
  echo
  echo -e "${C_BOLD}${C_BLUE}$1${C_RESET}"
}

if [ ! -f "$ENV_FILE" ]; then
  echo "[ERROR] .env not found at $ENV_FILE"
  exit 1
fi

BASE_DOMAIN="$(grep -E '^BASE_DOMAIN=' "$ENV_FILE" | tail -n1 | cut -d'=' -f2- | tr -d '[:space:]')"
if [ -z "$BASE_DOMAIN" ]; then
  echo "[ERROR] BASE_DOMAIN is missing in $ENV_FILE"
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
URL_RETRIES="${HEALTH_URL_RETRIES:-30}"
URL_RETRY_DELAY="${HEALTH_URL_RETRY_DELAY:-5}"

print_ok() {
  echo -e "${C_GREEN}✔ [PASS]${C_RESET} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

print_fail() {
  echo -e "${C_RED}✖ [FAIL]${C_RESET} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

print_warn() {
  echo -e "${C_YELLOW}⚠ [WARN]${C_RESET} $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

check_url() {
  local name="$1"
  local url="$2"
  local expected_regex="$3"

  local out code final attempt
  for attempt in $(seq 1 "$URL_RETRIES"); do
    out="$(curl -kLsS --max-redirs 10 -o /dev/null -w '%{http_code} %{url_effective}' "$url" 2>/dev/null || true)"
    code="${out%% *}"
    final="${out#* }"

    if echo "$code" | grep -Eq "$expected_regex"; then
      if [ "$attempt" -gt 1 ]; then
        print_ok "$name => HTTP $code ($final) after $attempt attempts"
      else
        print_ok "$name => HTTP $code ($final)"
      fi
      return
    fi

    if [ "$attempt" -lt "$URL_RETRIES" ]; then
      sleep "$URL_RETRY_DELAY"
    fi
  done

  if [ "$name" = "ERP" ] && sudo docker ps --format '{{.Names}}|{{.Status}}' | grep -q '^infra-erp-hrms-setup-1|Up'; then
    print_warn "$name => HTTP $code ($final) after $URL_RETRIES attempts (ERP setup still running; warm-up in progress)"
    return
  fi

  print_fail "$name => HTTP $code ($final) after $URL_RETRIES attempts"
}

check_port() {
  local name="$1"
  local host="$2"
  local port="$3"

  if timeout 3 bash -lc "</dev/tcp/$host/$port" >/dev/null 2>&1; then
    print_ok "$name port $port reachable"
  else
    print_fail "$name port $port unreachable"
  fi
}

check_container_health() {
  local name="$1"
  local filter="$2"

  local line
  line="$(sudo docker ps --format '{{.Names}}|{{.Status}}' | grep -E "$filter" | head -n1 || true)"
  if [ -z "$line" ]; then
    print_warn "$name container not found in running list"
    return
  fi

  local status="${line#*|}"
  if echo "$status" | grep -qiE 'healthy|Up'; then
    print_ok "$name container status: $status"
  else
    print_fail "$name container status: $status"
  fi
}

init_colors
print_header
echo -e "${C_CYAN}ℹ${C_RESET} Base domain: $BASE_DOMAIN"

print_section "[1/3] Checking web endpoints"
check_url "Portal" "https://portal.${BASE_DOMAIN}" '^(200|301|302)$'
check_url "ERP" "https://erp.${BASE_DOMAIN}" '^(200|301|302)$'
check_url "Nextcloud" "https://files.${BASE_DOMAIN}" '^(200|301|302)$'
check_url "Vaultwarden" "https://pw.${BASE_DOMAIN}" '^(200|301|302)$'
check_url "Uptime Kuma" "https://status.${BASE_DOMAIN}" '^(200|301|302)$'
check_url "Mail" "https://mail.${BASE_DOMAIN}" '^(200|301|302)$'

print_section "[2/3] Checking mail protocol ports"
check_port "SMTP" "mail.${BASE_DOMAIN}" 25
check_port "SMTPS" "mail.${BASE_DOMAIN}" 465
check_port "Submission" "mail.${BASE_DOMAIN}" 587
check_port "IMAP" "mail.${BASE_DOMAIN}" 143
check_port "IMAPS" "mail.${BASE_DOMAIN}" 993

print_section "[3/3] Checking key containers"
check_container_health "Traefik" '^reverse-proxy\|'
check_container_health "Mailu Front" '^mailu-front\|'
check_container_health "ERP App" '^infra-erp-app-1\|'
check_container_health "Nextcloud" '^nextcloud-app\|'
check_container_health "Vaultwarden" '^vaultwarden\|'

echo
echo -e "${C_BOLD}Summary:${C_RESET} ${C_GREEN}PASS=${PASS_COUNT}${C_RESET} ${C_YELLOW}WARN=${WARN_COUNT}${C_RESET} ${C_RED}FAIL=${FAIL_COUNT}${C_RESET}"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${C_RED}${C_BOLD}Result: Health check completed with failures.${C_RESET}"
  exit 1
fi
echo -e "${C_GREEN}${C_BOLD}Result: Health check passed.${C_RESET}"
exit 0
