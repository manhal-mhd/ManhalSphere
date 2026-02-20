#!/bin/bash
# Reset Mailu user password (including admin) via database
# Usage: ./reset-mailu-password.sh <username> <newpassword>

set -e

USERNAME="$1"
NEWPASS="$2"

if [ -z "$USERNAME" ] || [ -z "$NEWPASS" ]; then
  echo "Usage: $0 <username> <newpassword>"
  exit 1
fi

# Generate PBKDF2 hash for the new password
HASH=$(python3 -c "from passlib.hash import pbkdf2_sha256; print(pbkdf2_sha256.hash('$NEWPASS'))")

# Detect Mailu DB container (MariaDB or Postgres)
DB_CONTAINER=$(sudo docker ps --format '{{.Names}}' | grep -E 'mailu-db|mailu_mariadb|mailu_postgres|mailu-database')

if [ -z "$DB_CONTAINER" ]; then
  echo "Mailu database container not found. Please check your compose file."
  exit 1
fi

# Try MariaDB first
sudo docker exec -i "$DB_CONTAINER" sh -c "mysql -u root -p\"$MARIADB_ROOT_PASSWORD\" -D mailu -e \"UPDATE user SET password='$HASH' WHERE username='$USERNAME';\""
if [ $? -eq 0 ]; then
  echo "Password reset for user '$USERNAME' in MariaDB."
  sudo docker compose -f ../docker-compose.mail.yml restart
  exit 0
fi

# Try Postgres
sudo docker exec -i "$DB_CONTAINER" sh -c "psql -U mailu -d mailu -c \"UPDATE \"user\" SET password='$HASH' WHERE username='$USERNAME';\""
if [ $? -eq 0 ]; then
  echo "Password reset for user '$USERNAME' in Postgres."
  sudo docker compose -f ../docker-compose.mail.yml restart
  exit 0
fi

echo "Password reset failed. Please check DB credentials and container names."
exit 1
