#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$INFRA_DIR/.env"
MAILU_ENV_FILE="$INFRA_DIR/mailu.env"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

init_colors() {
  if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_CYAN='\033[36m'
  else
    C_RESET=''
    C_BOLD=''
    C_DIM=''
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
  echo -e "${C_BOLD}${C_CYAN}  ManhalSphere Pre-Check${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
}

print_section() {
  echo
  echo -e "${C_BOLD}${C_BLUE}$1${C_RESET}"
}

usage() {
  cat <<'EOF'
Usage:
  ./pre-check.sh
  ./pre-check.sh --generate-secrets-only
  ./pre-check.sh --auto-generate-secrets

Options:
  --generate-secrets-only   Generate suggested secrets/credentials only.
                            Does not modify any file.
  --auto-generate-secrets   Backup .env and mailu.env, generate fresh secrets,
                            and write them into required keys.
EOF
}

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

print_info() {
  echo -e "${C_CYAN}ℹ [INFO]${C_RESET} $1"
}

backup_file() {
  local file="$1"
  local ts="$2"
  local backup_path="${file}.bak.${ts}"
  cp "$file" "$backup_path"
  print_info "Backup created: $backup_path"
}

set_or_add_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped

  escaped="$(printf '%s' "$value" | sed -e 's/[&|]/\\&/g')"

  if grep -qE "^[[:space:]]*${key}=" "$file"; then
    sed -i -E "s|^[[:space:]]*${key}=.*$|${key}=${escaped}|" "$file"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$file"
  fi
}

generate_hex_32() {
  openssl rand -hex 32
}

generate_password() {
  openssl rand -base64 24 | tr -d '\n' | tr '/+' '_-'
}

auto_generate_secrets() {
  local ts new_mailu_secret new_db_root new_erp_db new_erp_admin

  if [ ! -f "$ENV_FILE" ]; then
    print_fail "Missing file: $ENV_FILE"
    return 1
  fi
  if [ ! -f "$MAILU_ENV_FILE" ]; then
    print_fail "Missing file: $MAILU_ENV_FILE"
    return 1
  fi

  require_cmd openssl "Install openssl"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    return 1
  fi

  ts="$(date +%Y%m%d-%H%M%S)"
  backup_file "$ENV_FILE" "$ts"
  backup_file "$MAILU_ENV_FILE" "$ts"

  new_mailu_secret="$(generate_hex_32)"
  new_db_root="$(generate_password)"
  new_erp_db="$(generate_password)"
  new_erp_admin="$(generate_password)"

  set_or_add_key "$MAILU_ENV_FILE" "SECRET_KEY" "$new_mailu_secret"
  set_or_add_key "$ENV_FILE" "MARIADB_ROOT_PASSWORD" "$new_db_root"
  set_or_add_key "$ENV_FILE" "ERP_DB_PASSWORD" "$new_erp_db"
  set_or_add_key "$ENV_FILE" "ERP_ADMIN_PASSWORD" "$new_erp_admin"

  echo
  print_ok "Secrets generated and written to env files"
  print_info "Updated $MAILU_ENV_FILE: SECRET_KEY"
  print_info "Updated $ENV_FILE: MARIADB_ROOT_PASSWORD, ERP_DB_PASSWORD, ERP_ADMIN_PASSWORD"

  echo
  echo "=== Generated Credentials (Store Securely) ==="
  echo "MARIADB_ROOT_PASSWORD=$new_db_root"
  echo "ERP_DB_PASSWORD=$new_erp_db"
  echo "ERP_ADMIN_PASSWORD=$new_erp_admin"
  echo "MAILU_SECRET_KEY=$new_mailu_secret"

  echo
  echo "Next steps:"
  echo "1) Re-deploy impacted services to apply new secrets:"
  echo "   cd $INFRA_DIR && sudo bash deploy-all.sh"
  echo "2) For existing live data, rotate matching app/database credentials carefully before restart."
}

generate_secrets_only() {
  local new_mailu_secret new_db_root new_erp_db new_erp_admin new_vw_admin

  require_cmd openssl "Install openssl"
  require_cmd python3 "Install python3"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    return 1
  fi

  new_mailu_secret="$(generate_hex_32)"
  new_db_root="$(generate_password)"
  new_erp_db="$(generate_password)"
  new_erp_admin="$(generate_password)"
  new_vw_admin="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"

  echo
  echo "=== Suggested Secrets (Dry Run - No File Changes) ==="
  echo "MAILU_SECRET_KEY=$new_mailu_secret"
  echo "MARIADB_ROOT_PASSWORD=$new_db_root"
  echo "ERP_DB_PASSWORD=$new_erp_db"
  echo "ERP_ADMIN_PASSWORD=$new_erp_admin"
  echo "VAULTWARDEN_ADMIN_TOKEN=$new_vw_admin"

  echo
  echo "Apply manually if you want:"
  echo "- $MAILU_ENV_FILE => SECRET_KEY"
  echo "- $ENV_FILE => MARIADB_ROOT_PASSWORD, ERP_DB_PASSWORD, ERP_ADMIN_PASSWORD"
  echo "- Vaultwarden compose/env => ADMIN_TOKEN (optional)"

  echo
  echo "Credentials checklist (manual):"
  echo "- ERP login: Administrator / ERP_ADMIN_PASSWORD"
  echo "- Mailu admin: postmaster@\${DOMAIN} / Mailu admin password"
  echo "- Mail users: full email + mailbox password"
  echo "- Nextcloud admin: set at first run"
  echo "- Portainer admin: set at first run"
}

require_cmd() {
  local cmd="$1"
  local install_hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    print_ok "Command available: $cmd"
  else
    print_fail "Command missing: $cmd ($install_hint)"
  fi
}

trim_whitespace() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

expand_refs() {
  local value="$1"
  value="${value//\$\{BASE_DOMAIN\}/${BASE_DOMAIN:-}}"
  value="${value//\$\{DOMAIN\}/${DOMAIN:-}}"
  printf '%s' "$value"
}

parse_env_file() {
  local file="$1"
  local raw line key value

  while IFS= read -r raw || [ -n "$raw" ]; do
    line="${raw%$'\r'}"
    line="$(trim_whitespace "$line")"

    [ -z "$line" ] && continue
    echo "$line" | grep -qE '^#' && continue
    echo "$line" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*=' || continue

    key="${line%%=*}"
    value="${line#*=}"
    value="$(trim_whitespace "$value")"

    if echo "$value" | grep -qE '^".*"$'; then
      value="${value#\"}"
      value="${value%\"}"
    elif echo "$value" | grep -qE "^'.*'$"; then
      value="${value#\'}"
      value="${value%\'}"
    fi

    value="$(expand_refs "$value")"
    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"
}

load_env_files() {
  if [ ! -f "$ENV_FILE" ]; then
    print_fail "Missing file: $ENV_FILE"
    return 1
  fi

  if [ ! -f "$MAILU_ENV_FILE" ]; then
    print_fail "Missing file: $MAILU_ENV_FILE"
    return 1
  fi

  parse_env_file "$ENV_FILE"
  parse_env_file "$MAILU_ENV_FILE"

  return 0
}

is_placeholder() {
  local value="$1"
  echo "$value" | grep -qiE '^(change_me|changeme|example|your_.*|set_me)$|change_me|replace_me|dummy|test123|admin$'
}

check_required_var() {
  local label="$1"
  local value="$2"

  if [ -z "$value" ]; then
    print_fail "$label is empty"
    return
  fi

  if is_placeholder "$value"; then
    print_warn "$label looks like a placeholder"
  else
    print_ok "$label is set"
  fi
}

detect_public_ip() {
  local ip
  ip="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  if [ -z "$ip" ]; then
    ip="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | head -n1 || true)"
  fi
  echo "$ip"
}

check_dns_a_record() {
  local host="$1"
  local expected_ip="$2"

  local resolved
  resolved="$(dig +short A "$host" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"

  if [ -z "$resolved" ]; then
    print_fail "DNS A missing for $host"
    return
  fi

  if [ -n "$expected_ip" ] && echo "$resolved" | grep -qw "$expected_ip"; then
    print_ok "DNS A $host => $resolved"
  elif [ -n "$expected_ip" ]; then
    print_fail "DNS A mismatch for $host (expected $expected_ip, got $resolved)"
  else
    print_warn "DNS A $host => $resolved (expected IP not provided/detected)"
  fi
}

check_txt_record_contains() {
  local fqdn="$1"
  local needle="$2"
  local label="$3"

  local txt
  txt="$(dig +short TXT "$fqdn" 2>/dev/null | tr -d '"' | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"

  if [ -z "$txt" ]; then
    print_warn "$label TXT record missing at $fqdn"
    return
  fi

  if echo "$txt" | grep -qi "$needle"; then
    print_ok "$label TXT valid at $fqdn"
  else
    print_warn "$label TXT found but does not contain '$needle' at $fqdn"
  fi
}

check_mx_record() {
  local domain="$1"
  local mail_host="$2"

  local mx
  mx="$(dig +short MX "$domain" 2>/dev/null | awk '{print $2}' | sed 's/\.$//' | tr '\n' ' ' | sed 's/[[:space:]]\+$//')"

  if [ -z "$mx" ]; then
    print_fail "MX record missing for $domain"
    return
  fi

  if echo "$mx" | grep -qw "$mail_host"; then
    print_ok "MX for $domain includes $mail_host"
  else
    print_warn "MX for $domain is '$mx' (expected to include $mail_host)"
  fi
}

print_requirements_guide() {
  cat <<EOF

=== Pre-Deployment Requirements ===
1) DNS A records to server IP:
   - portal.$BASE_DOMAIN
   - erp.$BASE_DOMAIN
   - files.$BASE_DOMAIN
   - pw.$BASE_DOMAIN
   - status.$BASE_DOMAIN
   - docker.$BASE_DOMAIN
   - mail.$BASE_DOMAIN
  - backup.$BASE_DOMAIN

2) Mail DNS records:
   - MX: $DOMAIN -> $MAIL_HOST
   - SPF TXT at $DOMAIN (contains 'v=spf1')
   - DMARC TXT at _dmarc.$DOMAIN (contains 'v=DMARC1')
   - DKIM TXT at <selector>._domainkey.$DOMAIN (commonly 'mail._domainkey')

3) Required env files:
   - $ENV_FILE
   - $MAILU_ENV_FILE
EOF
}

print_secret_generation_guide() {
  cat <<'EOF'

=== Secret Generation Guide ===
Use one of these commands when you need a strong secret:

- 64 hex chars (good for Mailu SECRET_KEY):
  openssl rand -hex 32

- URL-safe token (good for app passwords/tokens):
  python3 -c "import secrets; print(secrets.token_urlsafe(32))"

- Strong random password (base64):
  openssl rand -base64 24

Suggested fields to rotate from defaults/placeholders:
- .env: MARIADB_ROOT_PASSWORD, ERP_DB_PASSWORD, ERP_ADMIN_PASSWORD (optional custom)
- mailu.env: SECRET_KEY
EOF
}

print_credentials_guide() {
  cat <<EOF

=== Credentials Needed Per App ===
- ERPNext/HRMS:
  URL: https://$ERP_HOST
  User: Administrator
  Password: from ERP_ADMIN_PASSWORD (if not set, setup script default is 'admin')

- Mailu Admin:
  URL: https://$MAIL_HOST/sso/login
  User: postmaster@$DOMAIN (or MAIL_ADMIN_ADDRESS if customized)
  Password: set during Mailu bootstrap (not stored in env by default)

- Mailbox Login (webmail/IMAP/SMTP):
  URL: https://$MAIL_HOST/webmail/
  User: full mailbox email (e.g., user@$DOMAIN)
  Password: mailbox password created in Mailu admin

- Nextcloud:
  URL: https://$FILES_HOST
  Admin user/password: initial setup values at first-run (unless env-based bootstrap added)

- Vaultwarden:
  URL: https://$PASSWORDS_HOST
  Admin settings page (optional token): https://$PASSWORDS_HOST/admin
  Token source: ADMIN_TOKEN (if configured)

- Portainer:
  URL: https://$DOCKER_UI_HOST
  Credentials created on first login.

- Backrest Backup Manager:
  URL: https://backup.$BASE_DOMAIN
  Credentials created on first login.
EOF
}

main() {
  init_colors

  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
  fi

  if [ "${1:-}" = "--generate-secrets-only" ]; then
    print_header
    print_section "[DRY-RUN] Generating suggested secrets only"
    generate_secrets_only
    exit $?
  fi

  if [ "${1:-}" = "--auto-generate-secrets" ]; then
    print_header
    print_section "[AUTO] Generating and applying fresh secrets"
    auto_generate_secrets
    exit $?
  fi

  if [ -n "${1:-}" ]; then
    print_fail "Unknown option: $1"
    usage
    exit 1
  fi

  print_header

  print_section "[1/6] Checking local requirements"
  require_cmd docker "Install Docker Engine + Compose plugin"
  require_cmd curl "Install curl"
  require_cmd dig "Install dnsutils (Ubuntu/Debian)"
  require_cmd openssl "Install openssl"
  require_cmd timeout "Install coreutils"

  print_section "[2/6] Loading and validating env files"
  if ! load_env_files; then
    echo
    echo -e "${C_BOLD}Summary:${C_RESET} PASS=${PASS_COUNT} WARN=${WARN_COUNT} FAIL=${FAIL_COUNT}"
    exit 1
  fi

  BASE_DOMAIN="${BASE_DOMAIN:-}"
  DOMAIN="${DOMAIN:-}"
  MAIL_HOST="${MAIL_HOST:-mail.${BASE_DOMAIN}}"
  ERP_HOST="${ERP_HOST:-erp.${BASE_DOMAIN}}"
  PORTAL_HOST="${PORTAL_HOST:-portal.${BASE_DOMAIN}}"
  FILES_HOST="${FILES_HOST:-files.${BASE_DOMAIN}}"
  PASSWORDS_HOST="${PASSWORDS_HOST:-pw.${BASE_DOMAIN}}"
  STATUS_HOST="${STATUS_HOST:-status.${BASE_DOMAIN}}"
  DOCKER_UI_HOST="${DOCKER_UI_HOST:-docker.${BASE_DOMAIN}}"
  BACKUP_HOST="${BACKUP_HOST:-backup.${BASE_DOMAIN}}"
  LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
  MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
  ERP_DB_PASSWORD="${ERP_DB_PASSWORD:-}"
  ERP_ADMIN_PASSWORD="${ERP_ADMIN_PASSWORD:-}"

  SECRET_KEY="${SECRET_KEY:-}"
  SUBNET="${SUBNET:-}"
  HOSTNAMES="${HOSTNAMES:-}"
  TLS_FLAVOR="${TLS_FLAVOR:-}"
  WEBMAIL="${WEBMAIL:-}"

  check_required_var "BASE_DOMAIN" "$BASE_DOMAIN"
  check_required_var "LETSENCRYPT_EMAIL" "$LETSENCRYPT_EMAIL"
  check_required_var "MARIADB_ROOT_PASSWORD" "$MARIADB_ROOT_PASSWORD"
  check_required_var "ERP_DB_PASSWORD" "$ERP_DB_PASSWORD"

  if [ -z "$ERP_ADMIN_PASSWORD" ]; then
    print_warn "ERP_ADMIN_PASSWORD is not set in .env (fallback may be weak default)"
  else
    check_required_var "ERP_ADMIN_PASSWORD" "$ERP_ADMIN_PASSWORD"
  fi

  check_required_var "DOMAIN" "$DOMAIN"
  check_required_var "HOSTNAMES" "$HOSTNAMES"
  check_required_var "SECRET_KEY" "$SECRET_KEY"
  check_required_var "SUBNET" "$SUBNET"
  check_required_var "TLS_FLAVOR" "$TLS_FLAVOR"
  check_required_var "WEBMAIL" "$WEBMAIL"

  if [ "$DOMAIN" = "$BASE_DOMAIN" ]; then
    print_ok "DOMAIN matches BASE_DOMAIN"
  else
    print_warn "DOMAIN ($DOMAIN) differs from BASE_DOMAIN ($BASE_DOMAIN)"
  fi

  if echo "$HOSTNAMES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -qx "$MAIL_HOST"; then
    print_ok "MAIL_HOST is included in HOSTNAMES"
  else
    print_warn "MAIL_HOST ($MAIL_HOST) not found in HOSTNAMES ($HOSTNAMES)"
  fi

  if echo "$TLS_FLAVOR" | grep -Eq '^(letsencrypt|cert|notls|mail-letsencrypt|mail)$'; then
    print_ok "TLS_FLAVOR is valid: $TLS_FLAVOR"
  else
    print_fail "TLS_FLAVOR invalid: $TLS_FLAVOR"
  fi

  print_section "[3/6] Showing required DNS setup"
  print_requirements_guide

  print_section "[4/6] Checking DNS against expected public IP"
  EXPECTED_IP="${PRECHECK_EXPECTED_IP:-$(detect_public_ip)}"
  if [ -n "$EXPECTED_IP" ]; then
    print_info "Expected public IP: $EXPECTED_IP"
  else
    print_warn "Could not auto-detect public IP. Set PRECHECK_EXPECTED_IP manually for strict checks."
  fi

  check_dns_a_record "$PORTAL_HOST" "$EXPECTED_IP"
  check_dns_a_record "$ERP_HOST" "$EXPECTED_IP"
  check_dns_a_record "$FILES_HOST" "$EXPECTED_IP"
  check_dns_a_record "$PASSWORDS_HOST" "$EXPECTED_IP"
  check_dns_a_record "$STATUS_HOST" "$EXPECTED_IP"
  check_dns_a_record "$DOCKER_UI_HOST" "$EXPECTED_IP"
  check_dns_a_record "$MAIL_HOST" "$EXPECTED_IP"
  check_dns_a_record "$BACKUP_HOST" "$EXPECTED_IP"

  print_section "[5/6] Checking mail DNS records"
  check_mx_record "$DOMAIN" "$MAIL_HOST"
  check_txt_record_contains "$DOMAIN" 'v=spf1' 'SPF'
  check_txt_record_contains "_dmarc.$DOMAIN" 'v=DMARC1' 'DMARC'
  check_txt_record_contains "mail._domainkey.$DOMAIN" 'v=DKIM1' 'DKIM (mail selector)'

  print_section "[6/6] Printing secrets and credentials guidance"
  print_secret_generation_guide
  print_credentials_guide

  echo
  echo -e "${C_BOLD}Summary:${C_RESET} ${C_GREEN}PASS=${PASS_COUNT}${C_RESET} ${C_YELLOW}WARN=${WARN_COUNT}${C_RESET} ${C_RED}FAIL=${FAIL_COUNT}${C_RESET}"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${C_RED}${C_BOLD}Result: Pre-check completed with failures.${C_RESET}"
    exit 1
  fi
  echo -e "${C_GREEN}${C_BOLD}Result: Pre-check passed.${C_RESET}"
  exit 0
}

main "$@"
