#!/bin/bash
# Bootstrap Authentik IdP after first deployment
# - Waits for Authentik to be healthy
# - Creates initial superuser if needed
# - Prints admin URL and credentials

set -e

AUTHENTIK_HOST="idp.${BASE_DOMAIN:-octalearn.sd}"
ADMIN_USER="${AUTHENTIK_DEFAULT_USER_USERNAME:-admin}"
ADMIN_PASS="${AUTHENTIK_DEFAULT_USER_PASSWORD:-changeme-adminpass}"

# Wait for Authentik web UI to be up
until curl -sk https://${AUTHENTIK_HOST}/if/flow/login/ | grep -q "authentik"; do
  echo "Waiting for Authentik at https://${AUTHENTIK_HOST} ..."
  sleep 5
done

echo "\nAuthentik is up at https://${AUTHENTIK_HOST}"
echo "Login with:"
echo "  Username: $ADMIN_USER"
echo "  Password: $ADMIN_PASS"
echo "\nChange the password and configure SMTP, branding, and providers via the web UI."
