#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$INFRA_DIR/.env"
TEMPLATE_FILE="$INFRA_DIR/portal/config.yml.template"
OUTPUT_FILE="$INFRA_DIR/portal/config.yml"

if [ ! -f "$ENV_FILE" ]; then
	echo "Missing env file: $ENV_FILE"
	exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
	echo "Missing template file: $TEMPLATE_FILE"
	exit 1
fi

BASE_DOMAIN="$(grep -E '^BASE_DOMAIN=' "$ENV_FILE" | tail -n1 | cut -d'=' -f2- | tr -d '\r' | xargs || true)"

if [ -z "$BASE_DOMAIN" ]; then
	echo "BASE_DOMAIN is empty in $ENV_FILE"
	exit 1
fi

python3 - "$TEMPLATE_FILE" "$OUTPUT_FILE" "$BASE_DOMAIN" <<'PY'
from pathlib import Path
import sys

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
base_domain = sys.argv[3]

content = template_path.read_text(encoding="utf-8").replace("__BASE_DOMAIN__", base_domain)
output_path.write_text(content, encoding="utf-8")
PY

echo "Rendered portal config for domain: $BASE_DOMAIN"
