#!/usr/bin/env bash
set -euo pipefail

# ======================================================
# AIOps ONE-SHOT END-TO-END SANITY CHECK (READ-ONLY)
# - NO restarts, NO builds, NO changes
# - Correct internal-only checks
# ======================================================

HOST_IP="192.168.206.136"
MAX_TIME=6
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

banner () {
  echo
  echo "=============================="
  echo " AIOps ONE-SHOT E2E Sanity Check v2"
  echo " Host: $(hostname)  Time: $(date)"
  echo " VM IP: $HOST_IP"
  echo "=============================="
}

# ---- Expected containers (baseline) ----
EXPECTED_CONTAINERS=(
  aiops-rasa
  aiops-rasa-actions
  aiops-rag-service
  aiops-ml-gateway
  aiops-anomaly-service
  aiops-rag-db
  ai_orchestrator
  ai_pgvector
  prometheus
  node_exporter
  fluent_bit_shipper
  kibana
  elasticsearch
  onos_collector
  fastapi_heartbeat
  datalake_db
  onos
  librenms-clean
  librenms-db
  zabbix-web
  zabbix-server
  mariadb
)

# ---- Host HTTP endpoints (user-facing) ----
HTTP_CHECKS=(
  "Rasa Core|http://$HOST_IP:5005/status"
  "Rasa Actions|http://$HOST_IP:5055/health"
  "Elasticsearch|http://$HOST_IP:9200/"
  "Kibana|http://$HOST_IP:5601/api/status"
  "ONOS GUI|http://$HOST_IP:8181/onos/ui"
  "LibreNMS|http://$HOST_IP:8000/"
  "Zabbix Web|http://$HOST_IP:8081/"
  "Qdrant|http://$HOST_IP:6333/"
  "AI Orchestrator Docs|http://$HOST_IP:8088/docs"
  "Heartbeat API|http://$HOST_IP:8080/docs"
)

# ---- Internal-only health checks (inside containers) ----
# format: container|port|name
INTERNAL_CHECKS=(
  "aiops-ml-gateway|9000|ML-GW"
  "aiops-rag-service|8000|RAG"
  "aiops-anomaly-service|8100|ANOM"
  "ai_orchestrator|8088|ORCH"
  "fastapi_heartbeat|8080|HB"
)

# ---- TCP ports to verify open on host ----
TCP_PORTS=(
  "ONOS OpenFlow|6653"
  "ONOS SSH|8101"
  "Zabbix Server|10051"
  "Postgres datalake|5432"
  "Postgres pgvector|5433"
  "MariaDB|3306"
  "Qdrant HTTP|6333"
)

http_code () {
  local url="$1"
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$MAX_TIME" "$url" || echo 000000)
  echo "$code"
}

tcp_open () {
  local port="$1"
  timeout "$MAX_TIME" bash -lc "cat < /dev/null > /dev/tcp/127.0.0.1/$port" 2>/dev/null
}

banner

echo
echo "[1) Containers]"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | egrep -E "aiops-|prometheus|node_exporter|fluent_bit_shipper|kibana|elasticsearch|onos|librenms|zabbix|mariadb" || true
echo

for c in "${EXPECTED_CONTAINERS[@]}"; do
  if docker ps --format "{{.Names}}" | grep -qx "$c"; then
    echo -e "${GREEN}✅ $c (running)${NC}"
  else
    echo -e "${RED}❌ $c (NOT running)${NC}"
    FAIL=1
  fi
done

echo
echo "[2) HTTP Endpoints]"
for chk in "${HTTP_CHECKS[@]}"; do
  IFS="|" read -r name url <<<"$chk"
  code=$(http_code "$url")
  if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
    echo -e "${GREEN}✅ $name (HTTP $code) $url${NC}"
  else
    echo -e "${RED}❌ $name (HTTP $code) $url${NC}"
    FAIL=1
  fi
done

echo
echo "[3) Internal Health (docker exec)]"
for chk in "${INTERNAL_CHECKS[@]}"; do
  IFS="|" read -r c port tag <<<"$chk"

  if ! docker ps --format "{{.Names}}" | grep -qx "$c"; then
    echo -e "${RED}❌ $c → not running${NC}"
    FAIL=1
    continue
  fi

  out="$(docker exec "$c" sh -lc "
    if command -v curl >/dev/null 2>&1; then
      curl -s -o /dev/null -w \"%{http_code}\" http://127.0.0.1:$port/health || echo 000000
    elif command -v wget >/dev/null 2>&1; then
      wget -qO- http://127.0.0.1:$port/health >/dev/null && echo 200 || echo 000000
    elif command -v python3 >/dev/null 2>&1; then
      python3 - <<PY
import urllib.request
try:
    r = urllib.request.urlopen('http://127.0.0.1:$port/health', timeout=5)
    print(r.status)
except Exception as e:
    print('000000')
PY
    else
      echo NO_HTTP_CLIENT
    fi
  " 2>&1 | tr -d '\r' | tail -n 1)"

  if [[ "$out" == "200" ]]; then
    echo -e "${GREEN}✅ $c → /health OK${NC}"
  elif [[ "$out" == "NO_HTTP_CLIENT" ]]; then
    echo -e "${GREEN}✅ $c → internal-only (no curl/wget/python), skipping health${NC}"
  else
    echo -e "${RED}❌ $c → /health FAIL ($out)${NC}"
    FAIL=1
  fi
done

echo
echo "[4) Host TCP Ports]"
for p in "${TCP_PORTS[@]}"; do
  IFS="|" read -r name port <<<"$p"
  if tcp_open "$port"; then
    echo -e "${GREEN}✅ $name open (127.0.0.1:$port)${NC}"
  else
    echo -e "${RED}❌ $name closed (127.0.0.1:$port)${NC}"
    FAIL=1
  fi
done

echo
echo "[5) Bot E2E Pipeline]"
PARSE_CODE=$(http_code "http://$HOST_IP:5005/model/parse")
if [[ "$PARSE_CODE" =~ ^(200|401|403)$ ]]; then
  echo -e "${GREEN}✅ NLU parse endpoint reachable (HTTP $PARSE_CODE)${NC}"
else
  echo -e "${RED}❌ NLU parse endpoint not reachable (HTTP $PARSE_CODE)${NC}"
  FAIL=1
fi

BOT_RESP="$(curl -s --max-time "$MAX_TIME" -X POST "http://$HOST_IP:5005/webhooks/rest/webhook" \
  -H "Content-Type: application/json" \
  -d '{"sender":"sanity-user","message":"Why is CPU high on RB?"}' || true)"

if echo "$BOT_RESP" | grep -q "text"; then
  echo -e "${GREEN}✅ Bot response healthy${NC}"
else
  echo -e "${RED}❌ Bot response empty/unhealthy${NC}"
  FAIL=1
fi

echo
echo "=============================="
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}✅ SANITY CHECK PASSED${NC}"
else
  echo -e "${RED}❌ SANITY CHECK FAILED — see red items.${NC}"
fi
echo "(Script made NO changes.)"
echo "=============================="
