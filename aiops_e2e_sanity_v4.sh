#!/usr/bin/env bash
set -euo pipefail

# ======================================================
# AIOps ONE-SHOT END-TO-END SANITY CHECK v4 (READ-ONLY)
# - NO restarts, NO builds, NO changes
# - Adds ChatGPT Bridge + /ai/chatgpt proxy checks
# - Heartbeat uses /docs (no /health endpoint)
# - Rasa NLU parse uses POST (fixes 405)
# - Treats 429 from ChatGPT path as "reachable" (quota/rate-limit)
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
  echo " AIOps ONE-SHOT E2E Sanity Check v4"
  echo " Host: $(hostname)  Time: $(date)"
  echo " VM IP: $HOST_IP"
  echo "=============================="
}

ok ()   { echo -e "${GREEN}✅ $*${NC}"; }
bad ()  { echo -e "${RED}❌ $*${NC}"; FAIL=1; }

curl_code () {
  local url="$1"
  curl -s -o /dev/null -w "%{http_code}" --max-time "$MAX_TIME" "$url" || echo 000000
}

curl_post_code () {
  local url="$1"
  local data="$2"
  curl -s -o /dev/null -w "%{http_code}" --max-time "$MAX_TIME" \
    -X POST "$url" -H "Content-Type: application/json" -d "$data" || echo 000000
}

# ---- Expected containers (baseline + ChatGPT bridge) ----
EXPECTED_CONTAINERS=(
  aiops-rasa
  aiops-rasa-actions
  aiops-rag-service
  aiops-ml-gateway
  aiops-anomaly-service
  aiops-rag-db
  aiops-chatgpt-bridge
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

banner

echo
echo "[1) Containers]"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | egrep -E "aiops-|prometheus|node_exporter|fluent_bit_shipper|kibana|elasticsearch|onos|librenms|zabbix|mariadb" || true
echo

for c in "${EXPECTED_CONTAINERS[@]}"; do
  if docker ps --format "{{.Names}}" | grep -qx "$c"; then
    ok "$c (running)"
  else
    bad "$c (NOT running)"
  fi
done

echo
echo "[2) HTTP Endpoints (host-facing)]"
declare -a HOST_HTTP_CHECKS=(
  "Rasa Core|http://$HOST_IP:5005/status"
  "Rasa Actions|http://$HOST_IP:5055/health"
  "ChatGPT Bridge Health|http://$HOST_IP:9110/health"
  "Elasticsearch|http://$HOST_IP:9200/"
  "Kibana|http://$HOST_IP:5601/api/status"
  "ONOS GUI|http://$HOST_IP:8181/onos/ui"
  "LibreNMS|http://$HOST_IP:8000/"
  "Zabbix Web|http://$HOST_IP:8081/"
  "Qdrant|http://$HOST_IP:6333/"
  "AI Orchestrator Docs|http://$HOST_IP:8088/docs"
  "Heartbeat Docs|http://$HOST_IP:8080/docs"
)

for chk in "${HOST_HTTP_CHECKS[@]}"; do
  IFS="|" read -r name url <<<"$chk"
  code="$(curl_code "$url")"
  if [[ "$code" =~ ^(200|301|302|401|403)$ ]]; then
    ok "$name (HTTP $code) $url"
  else
    bad "$name (HTTP $code) $url"
  fi
done

echo
echo "[3) Internal Health (docker exec)]"
internal_checks=(
  "aiops-chatgpt-bridge|9100|BRIDGE"
  "aiops-ml-gateway|9000|ML-GW"
  "aiops-rag-service|8000|RAG"
  "aiops-anomaly-service|8100|ANOM"
  "ai_orchestrator|8088|ORCH"
  "fastapi_heartbeat|80|HB-DOCS"
)

for chk in "${internal_checks[@]}"; do
  IFS="|" read -r c port tag <<<"$chk"
  if ! docker ps --format "{{.Names}}" | grep -qx "$c"; then
    bad "$c → not running"
    continue
  fi

  # Heartbeat: check /docs, others: /health
  path="/health"
  [[ "$c" == "fastapi_heartbeat" ]] && path="/docs"

  out="$(docker exec "$c" sh -lc "
    if command -v curl >/dev/null 2>&1; then
      curl -s -o /dev/null -w \"%{http_code}\" http://127.0.0.1:$port$path || echo 000000
    elif command -v wget >/dev/null 2>&1; then
      wget -qO- http://127.0.0.1:$port$path >/dev/null && echo 200 || echo 000000
    elif command -v python3 >/dev/null 2>&1; then
      python3 - <<PY
import urllib.request
try:
    r = urllib.request.urlopen(\"http://127.0.0.1:$port$path\", timeout=5)
    print(r.status)
except Exception:
    print(\"000000\")
PY
    else
      echo NO_HTTP_CLIENT
    fi
  " 2>/dev/null || true)"

  if echo "$out" | grep -q "^200$"; then
    ok "$c → $path OK"
  elif echo "$out" | grep -q "NO_HTTP_CLIENT"; then
    ok "$c → internal-only (no curl/wget), skipping"
  else
    bad "$c → $path FAIL ($out)"
  fi
done

echo
echo "[4) Host TCP Ports]"
tcp_ports=(
  "6653|ONOS OpenFlow"
  "8101|ONOS SSH"
  "9110|ChatGPT Bridge Host Port"
  "10051|Zabbix Server"
  "5432|Postgres datalake"
  "5433|Postgres pgvector"
  "3306|MariaDB"
  "6333|Qdrant HTTP"
)

for p in "${tcp_ports[@]}"; do
  IFS="|" read -r port label <<<"$p"
  if timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
    ok "$label open (127.0.0.1:$port)"
  else
    bad "$label CLOSED (127.0.0.1:$port)"
  fi
done

echo
echo "[5) Bot E2E Pipeline]"
# NLU parse (POST)
parse_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$MAX_TIME" \
  -X POST "http://$HOST_IP:5005/model/parse" \
  -H "Content-Type: application/json" \
  -d '{"text":"Why is CPU high on RB?"}' || echo 000000)"

if [[ "$parse_code" =~ ^(200|401|403)$ ]]; then
  ok "NLU parse reachable (HTTP $parse_code)"
else
  bad "NLU parse failed (HTTP $parse_code)"
fi

# Full webhook
webhook_resp="$(curl -s --max-time "$MAX_TIME" \
  -X POST "http://$HOST_IP:5005/webhooks/rest/webhook" \
  -H "Content-Type: application/json" \
  -d '{"sender":"smoke-user","message":"Why is CPU high on RB?"}' || true)"

if echo "$webhook_resp" | grep -q "recipient_id"; then
  ok "Bot response healthy"
else
  bad "Bot response empty/unhealthy"
fi

echo
echo "[6) ChatGPT path reachability (internal only)]"
if docker ps --format "{{.Names}}" | grep -qx "aiops-ml-gateway"; then
  # Call ml-gateway /ai/chatgpt from inside (accept 200 or 429 as reachable)
  chatgpt_code="$(docker exec aiops-ml-gateway sh -lc "
    if command -v curl >/dev/null 2>&1; then
      curl -s -o /dev/null -w '%{http_code}' \
        -X POST http://127.0.0.1:9000/ai/chatgpt \
        -H 'Content-Type: application/json' \
        -d '{\"message\":\"sanity hello\",\"context\":\"smoke\"}' || echo 000000
    else
      python3 - <<PY
import urllib.request, json, sys
data=b'{\"message\":\"sanity hello\",\"context\":\"smoke\"}'
req=urllib.request.Request('http://127.0.0.1:9000/ai/chatgpt', data=data, headers={'Content-Type':'application/json'})
try:
    r=urllib.request.urlopen(req, timeout=6)
    print(r.status)
except Exception as e:
    # try to surface status if present
    msg=str(e)
    if 'HTTP Error' in msg:
        print(msg.split('HTTP Error ')[1].split(':')[0])
    else:
        print('000000')
PY
    fi
  " 2>/dev/null || true)"

  if [[ "$chatgpt_code" =~ ^(200|429)$ ]]; then
    ok "ML-GW /ai/chatgpt reachable (HTTP $chatgpt_code)"
  else
    bad "ML-GW /ai/chatgpt FAILED (HTTP $chatgpt_code)"
  fi
else
  bad "aiops-ml-gateway not running → cannot test /ai/chatgpt"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  ok "SANITY CHECK PASSED (all green)"
else
  bad "SANITY CHECK FAILED — see red items."
fi
