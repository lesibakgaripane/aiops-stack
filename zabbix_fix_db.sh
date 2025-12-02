#!/usr/bin/env bash
set -e

echo "=============================="
echo " Zabbix DB Fix - Detect compose file"
echo "=============================="

cd ~/aiops-stack

# Detect which compose file was used to create zabbix-server
CFG_LABEL=$(docker inspect zabbix-server --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}' 2>/dev/null || true)

if [ -z "$CFG_LABEL" ]; then
  echo "!! Could not detect compose file for zabbix-server (no compose labels found)."
  echo "   Aborting to avoid touching other services."
  exit 1
fi

# In most cases this is a single path like 'docker-compose.monitoring.yml'
COMPOSE_FILE=$(echo "$CFG_LABEL" | cut -d',' -f1)

echo "[*] Detected compose file: $COMPOSE_FILE"

echo "[*] Writing zabbix-db-override.yml (sets DB_SERVER_HOST=mariadb, DB_SERVER_PORT=3306)"

cat << 'YML' > zabbix-db-override.yml
services:
  zabbix-server:
    environment:
      DB_SERVER_HOST: mariadb
      DB_SERVER_PORT: "3306"
YML

echo "[*] Applying override only to zabbix-server (other services untouched)..."

docker compose -f "$COMPOSE_FILE" -f zabbix-db-override.yml up -d zabbix-server

echo "[*] Waiting 10 seconds for Zabbix server to initialise..."
sleep 10

echo "[*] Showing last 40 lines of zabbix-server logs:"
docker logs zabbix-server --tail=40

echo "=============================="
echo " Zabbix DB Fix completed"
echo "=============================="
