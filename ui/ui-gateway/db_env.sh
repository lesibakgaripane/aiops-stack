#!/usr/bin/env bash
set -euo pipefail

# Defaults
export DB_HOST="${DB_HOST:-127.0.0.1}"
export DB_PORT="${DB_PORT:-3306}"

# Try pull creds from mariadb container env
if docker ps --format '{{.Names}}' | grep -qx mariadb; then
  export DB_USER="${DB_USER:-$(docker exec mariadb sh -lc 'printenv MYSQL_USER || true')}"
  export DB_PASS="${DB_PASS:-$(docker exec mariadb sh -lc 'printenv MYSQL_PASSWORD || printenv MYSQL_ROOT_PASSWORD || true')}"
  export DB_NAME="${DB_NAME:-$(docker exec mariadb sh -lc 'printenv MYSQL_DATABASE || true')}"
fi

# Fallbacks if container env not set
export DB_USER="${DB_USER:-root}"
export DB_PASS="${DB_PASS:-password}"
export DB_NAME="${DB_NAME:-aiops_auth}"

echo "DB_HOST=$DB_HOST"
echo "DB_PORT=$DB_PORT"
echo "DB_USER=$DB_USER"
echo "DB_NAME=$DB_NAME"
