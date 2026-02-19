#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$INFRA_DIR"

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
  echo -e "${C_BOLD}${C_CYAN}  Office-in-a-Box Reset Utility${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}========================================${C_RESET}"
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

print_info() {
  echo -e "${C_CYAN}ℹ${C_RESET} $1"
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    sudo docker compose "$@"
  else
    sudo docker-compose "$@"
  fi
}

reset_stack() {
  local compose_file="$1"
  local label="$2"

  if [ ! -f "$compose_file" ]; then
    print_fail "Compose file not found: $compose_file"
    return 1
  fi

  echo
  echo -e "${C_BOLD}${C_BLUE}[RESET]${C_RESET} $label"
  if compose_cmd -f "$compose_file" down -v; then
    print_ok "$label reset completed"
  else
    print_fail "$label reset failed"
    return 1
  fi
}

reset_all() {
  reset_stack docker-compose.mail.yml "Mailu"
  reset_stack docker-compose.vaultwarden.yml "Vaultwarden"
  reset_stack docker-compose.nextcloud.yml "Nextcloud"
  reset_stack docker-compose.erpnext-hrms.yml "ERPNext + HRMS"
  reset_stack docker-compose.yml "Core stack (Traefik/Portal/Monitoring/WireGuard)"
}

print_menu() {
  print_header
  cat <<'EOF'

Choose what to reset:
  1) Mailu
  2) ERPNext + HRMS
  3) Nextcloud
  4) Vaultwarden
  5) Core stack (Traefik/Portal/Monitoring/WireGuard)
  6) All stacks (full fresh reset)
  7) Exit
EOF
}

confirm_or_exit() {
  local target="$1"
  echo
  print_warn "This will DELETE persistent data for: $target"
  print_info "Type RESET to continue:"
  read -r confirm
  if [ "$confirm" != "RESET" ]; then
    print_warn "Cancelled. No changes made."
    exit 0
  fi
}

main() {
  print_menu
  printf '\nEnter option [1-7]: '
  read -r choice

  case "$choice" in
    1)
      confirm_or_exit "Mailu"
      reset_stack docker-compose.mail.yml "Mailu"
      ;;
    2)
      confirm_or_exit "ERPNext + HRMS"
      reset_stack docker-compose.erpnext-hrms.yml "ERPNext + HRMS"
      ;;
    3)
      confirm_or_exit "Nextcloud"
      reset_stack docker-compose.nextcloud.yml "Nextcloud"
      ;;
    4)
      confirm_or_exit "Vaultwarden"
      reset_stack docker-compose.vaultwarden.yml "Vaultwarden"
      ;;
    5)
      confirm_or_exit "Core stack (Traefik/Portal/Monitoring/WireGuard)"
      reset_stack docker-compose.yml "Core stack (Traefik/Portal/Monitoring/WireGuard)"
      ;;
    6)
      confirm_or_exit "ALL STACKS"
      reset_all
      ;;
    7)
      print_info "Exit."
      exit 0
      ;;
    *)
      print_fail "Invalid option: $choice"
      exit 1
      ;;
  esac

  echo
  print_ok "Reset completed."
  echo -e "${C_BOLD}Next:${C_RESET} To redeploy run: cd $INFRA_DIR && sudo bash deploy-all.sh"
}

init_colors
main "$@"
