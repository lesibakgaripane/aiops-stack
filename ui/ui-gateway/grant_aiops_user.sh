#!/usr/bin/env bash
set -euo pipefail

echo "==> Granting aiops user privileges on aiops_auth"

docker exec -i mariadb sh -lc '
  set -e
  ROOTPW="${MYSQL_ROOT_PASSWORD:-}"
  if [ -n "$ROOTPW" ]; then
    mysql -uroot -p"$ROOTPW" <<SQL
GRANT ALL PRIVILEGES ON aiops_auth.* TO "aiops"@"%" IDENTIFIED BY "${MYSQL_PASSWORD:-${MYSQL_ROOT_PASSWORD:-password}}";
FLUSH PRIVILEGES;
SQL
  else
    mysql -uroot <<SQL
GRANT ALL PRIVILEGES ON aiops_auth.* TO "aiops"@"%" IDENTIFIED BY "${MYSQL_PASSWORD:-password}";
FLUSH PRIVILEGES;
SQL
  fi
'

echo "✅ aiops user granted access"
