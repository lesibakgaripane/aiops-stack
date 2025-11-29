#!/usr/bin/env bash
set -euo pipefail

# ======================================================
# AIOps ONE-SHOT END-TO-END SANITY CHECK (READ-ONLY)
# - NO restarts, NO builds, NO changes
# - Treat internal-only services correctly
# ======================================================

HOST_IP="192.168.206.136"
MAX_TIME=6
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

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

HOST_HTTP_CHECKS=(
  "Rasa Core|http://$HOST_IP:5005/status|aiops-rasa"
  "Rasa Actions|http://$HOST_IP:5055/health|aiops-rasa-actions"
  "ML Gateway|http://$HOST_IP:9000/health|aiops-ml-gateway"
  "RAG Service|http://$HOST_IP:8000/health|aiops-rag-service"
  "Anomaly Service|http://$HOST_IP:8100/health|aiops-anomaly-service"
  "Elasticsearch|http://$HOST_IP:9200/|elasticsearch"
  "Kibana|http://$HOST_IP:5601/api/status|kibana"
  "ONOS GUI|http://$HOST_IP:8181/onos/ui|onos"
  "LibreNMS|http://$HOST_IP:8000/|librenms-clean"
  "Zabbix Web|http://$HOST_IP:8081/|zabbix-web"
  "Qdrant|http://$HOST_IP:6333/|aiops-rag-db"
  "AI Orchestrator Docs|http://$HOST_IP:8088/docs|ai_orchestrator"
  "Heartbeat API|http://$HOST_IP:8080/docs|fastapi_heartbeat"
  # FluentBit metrics is OPTIONAL unless port is published
  "FluentBit Metrics (optional)|http://$HOST_IP:2020/api/v1/metrics/prometheus|fluent_bit_shipper|OPTIONAL"
)

banner () {
  echo
  echo "=============================="
  echo " AIOps ONE-SHOT E2E Sanity Check"
  echo " Host: $(hostname)  Time: $(date)"
  echo " VM IP: $HOST_IP"
  echo "=============================="
}

is_running () {
  docker ps --format '{{.Names}}' | grep -qx "$1"
}

container_ports_published () {
  # returns 0 if container has any host-published ports
  docker ps --format '{{.Names}} {{.Ports}}' | awk -v c="$1" '$1==c {print $0}' | grep -q '0.0.0.0'
}

http_code () {
  local url="$1"
  curl -s -o /dev/null -w "%{http_code}" --max-time "$MAX_TIME" "$url" || echo "000000"
}

green () { echo -e "${GREEN}✅ $*${NC}"; }
red () { echo -e "${RED}❌ $*${NC}"; FAIL=1; }

banner

echo
echo "[1) Containers]"
docker ps --format "  {{.Names | printf \"%-22s\"}} {{.Status | printf \"%-24s\"}} {{.Ports}}" | grep -E "aiops-|prometheus|node_exporter|fluent_bit_shipper|kibana|elasticsearch|onos|librenms|zabbix|mariadb" || true

for c in "${EXPECTED_CONTAINERS[@]}"; do
  if is_running "$c"; then
    green "$c (running)"
  else
    red "$c (NOT running)"
  fi
done

echo
echo "[2) HTTP Endpoints]"
for item in "${HOST_HTTP_CHECKS[@]}"; do
  IFS='|' read -r name url container optflag <<<"$item"
  code="$(http_code "$url")"

  # If OPTIONAL and not published, skip fail
  if [[ "${optflag:-}" == "OPTIONAL" ]] && ! container_ports_published "$container"; then
    echo -e "${GREEN}✅ $name skipped (internal-only, not published)${NC}  $url"
    continue
  fi

  # If service is internal-only (no published ports), don't fail host HTTP
  if ! container_ports_published "$container"; then
    echo -e "${GREEN}✅ $name internal-only (host check skipped)${NC}  $url"
    continue
  fi

  if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
    green "$name (HTTP $code) $url"
  else
    red "$name (HTTP $code) $url"
  fi
done

echo
echo "[3) Internal Health (docker exec)]"
internal_checks=(
  "aiops-ml-gateway|9000|ML-GW"
  "aiops-rag-service|8000|RAG"
  "aiops-anomaly-service|8100|ANOM"
  "ai_orchestrator|8088|ORCH"
  "fastapi_heartbeat|8080|HB"
)

for chk in "${internal_checks[@]}"; do
  IFS='|' read -r c port tag <<<"$chk"
  if ! is_running "$c"; then
    red "$c → not running"
    continue
  fi
  out="$(docker exec "$c" python3 - <<PY 2>/dev/null || true
import urllib.request
try:
    r = urllib.request.urlopen("http://127.0.0.1:$port/health", timeout=5)
    print(r.status)
except Exception as e:
    print("ERR", e)
PY
)"
  if echo "$out" | grep -q '^200'; then
    green "$c → /health OK"
  else
    red "$c → /health FAIL ($out)"
  fi
done

echo
echo "[4) Host TCP Ports]"
tcp_ports=(
  "ONOS OpenFlow|6653"
  "ONOS SSH|8101"
  "Zabbix Server|10051"
  "Postgres datalake|5432"
  "Postgres pgvector|5433"
  "MariaDB|3306"
  "Qdrant|6333"
)
for tp in "${tcp_ports[@]}"; do
  IFS='|' read -r name port <<<"$tp"
  if timeout 2 bash -c ":</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
    green "$name open (127.0.0.1:$port)"
  else
    red "$name closed (127.0.0.1:$port)"
  fi
done

echo
echo "[5) Bot E2E Pipeline]"
if is_running aiops-rasa; then
  parse="$(curl -s --max-time "$MAX_TIME" -X POST "http://$HOST_IP:5005/model/parse" \
    -H "Content-Type: application/json" \
    -d '{"text":"Why is CPU high on RB?"}' || true)"
  if echo "$parse" | grep -q '"intent"'; then
    green "NLU parse returned intent"
  else
    red "NLU parse failed"
  fi

  webhook="$(curl -s --max-time "$MAX_TIME" -X POST "http://$HOST_IP:5005/webhooks/rest/webhook" \
    -H "Content-Type: application/json" \
    -d '{"sender":"sanity-user","message":"Why is CPU high on RB?"}' || true)"
  if echo "$webhook" | grep -q '"text"'; then
    green "Bot response healthy"
  else
    red "Webhook empty/failed"
  fi
else
  red "aiops-rasa not running → skipping bot pipeline"
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
exit "$FAIL"
