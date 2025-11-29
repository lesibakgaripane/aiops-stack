#!/usr/bin/env bash
set -euo pipefail

DB_NAME="aiops_auth"

echo "==> Creating DB/table inside mariadb container as root"

docker exec -i mariadb sh -lc '
  set -e
  ROOTPW="${MYSQL_ROOT_PASSWORD:-}"
  if [ -n "$ROOTPW" ]; then
    mysql -uroot -p"$ROOTPW" <<SQL
CREATE DATABASE IF NOT EXISTS aiops_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE aiops_auth;
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) NOT NULL UNIQUE,
  role ENUM("ADMIN","SUPER_USER","END_USER") NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
SQL
  else
    # if root password not set, try passwordless root (common in dev)
    mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS aiops_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE aiops_auth;
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(64) NOT NULL UNIQUE,
  role ENUM("ADMIN","SUPER_USER","END_USER") NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
SQL
  fi
'

echo "✅ aiops_auth DB + users table ready"
