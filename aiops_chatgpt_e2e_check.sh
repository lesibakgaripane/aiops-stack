#!/usr/bin/env bash
set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

banner () {
  echo
  echo "=============================="
  echo " AIOps ChatGPT E2E Check"
  echo " Host: $(hostname)  Time: $(date)"
  echo "=============================="
}

ok ()  { echo -e "${GREEN}✅ $*${NC}"; }
warn (){ echo -e "${YELLOW}⚠️  $*${NC}"; }
bad () { echo -e "${RED}❌ $*${NC}"; }

banner

FAIL=0

echo
echo "[1) Containers]"

if docker ps --format '{{.Names}}' | grep -qx "aiops-ml-gateway"; then
  ok "aiops-ml-gateway running"
else
  bad "aiops-ml-gateway NOT running"
  FAIL=1
fi

if docker ps --format '{{.Names}}' | grep -qx "aiops-chatgpt-bridge"; then
  ok "aiops-chatgpt-bridge running"
else
  bad "aiops-chatgpt-bridge NOT running"
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  bad "Required containers missing – aborting ChatGPT E2E."
  exit 1
fi

echo
echo "[2) Internal reachability (ML-GW → Bridge /health)]"

BRIDGE_RESP="$(docker exec aiops-ml-gateway sh -lc \
  'curl -s -w "___HTTP_CODE___%{http_code}" http://aiops-chatgpt-bridge:9100/health || echo "___HTTP_CODE___000"' 2>/dev/null || echo "___HTTP_CODE___000")"

BRIDGE_CODE="${BRIDGE_RESP##*___HTTP_CODE___}"
BRIDGE_BODY="${BRIDGE_RESP%___HTTP_CODE___*}"

echo "$BRIDGE_BODY"
echo "HTTP $BRIDGE_CODE"

if [ "$BRIDGE_CODE" = "200" ]; then
  ok "ML-GW can reach bridge /health"
else
  bad "ML-GW cannot reach bridge /health (HTTP $BRIDGE_CODE)"
  exit 1
fi

echo
echo "[3) Real ChatGPT answer test via ML-GW /ai/chatgpt]"

CHAT_RESP="$(docker exec aiops-ml-gateway sh -lc \
  'curl -s -w "___HTTP_CODE___%{http_code}" \
     -X POST http://127.0.0.1:9000/ai/chatgpt \
     -H "Content-Type: application/json" \
     -d "{\"message\":\"sanity hello\",\"context\":\"smoke-test\"}" || echo "___HTTP_CODE___000"' 2>/dev/null || echo "___HTTP_CODE___000")"

CHAT_CODE="${CHAT_RESP##*___HTTP_CODE___}"
CHAT_BODY="${CHAT_RESP%___HTTP_CODE___*}"

echo "HTTP $CHAT_CODE"
echo "$CHAT_BODY"

if [ "$CHAT_CODE" != "200" ]; then
  bad "Unexpected HTTP code from /ai/chatgpt: $CHAT_CODE"
  exit 1
fi

if echo "$CHAT_BODY" | grep -q 'Invalid/disabled OPENAI_API_KEY'; then
  warn "ChatGPT path reachable but OpenAI key is invalid/disabled."
  warn "Infra is OK, external LLM is just disabled until a real OPENAI_API_KEY is configured."
  exit 0
fi

ok "ChatGPT E2E succeeded with a valid response."
exit 0
