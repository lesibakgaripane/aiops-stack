#!/usr/bin/env bash
set -euo pipefail

# ============================================
# AIOps ChatGPT E2E Check (READ-ONLY)
# Tests:
#   1. Required containers running
#   2. ML-GW → Bridge /health (internal DNS)
#   3. ML-GW → ChatGPT → OpenAI (E2E)
#
# Detects:
#   - OpenAI quota/rate limit (429)
#   - Auth errors
#   - Bridge unreachable
#   - Unexpected failures
# ============================================

MAX_TIME=25
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok ()  { echo -e "${GREEN}✅ $*${NC}"; }
bad () { echo -e "${RED}❌ $*${NC}"; FAIL=1; }

echo
echo "=============================="
echo " AIOps ChatGPT E2E Check"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="
echo

# ---------------------------------------------------------
# 1) REQUIRED CONTAINERS
# ---------------------------------------------------------
echo "[1) Containers]"
for c in aiops-ml-gateway aiops-chatgpt-bridge; do
  if docker ps --format "{{.Names}}" | grep -qx "$c"; then
    ok "$c running"
  else
    bad "$c NOT running"
  fi
done
echo

# ---------------------------------------------------------
# 2) ML-GW → BRIDGE INTERNAL HEALTH CHECK
# ---------------------------------------------------------
echo "[2) Internal reachability]"

bridge_health="$(docker exec -i aiops-ml-gateway python3 - <<'PY'
import urllib.request, json
try:
    r = urllib.request.urlopen("http://aiops-chatgpt-bridge:9100/health", timeout=5)
    print("HTTP", r.status)
    print(r.read().decode())
except Exception as e:
    print("ERR", e)
PY
)"

echo "$bridge_health"

if echo "$bridge_health" | grep -q "HTTP 200"; then
  ok "ML-GW can reach bridge /health"
else
  bad "ML-GW cannot reach bridge /health"
fi
echo

# ---------------------------------------------------------
# 3) REAL CHATGPT → OPENAI E2E TEST
# ---------------------------------------------------------
echo "[3) Real ChatGPT answer test]"

answer_out="$(docker exec -i aiops-ml-gateway python3 - <<'PY'
import urllib.request, json, sys
payload = {
    "message": "E2E test: say hello in one short sentence.",
    "context": "aiops_chatgpt_e2e_check"
}

req = urllib.request.Request(
    "http://127.0.0.1:9000/ai/chatgpt",
    data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json"}
)

try:
    r = urllib.request.urlopen(req, timeout=25)
    print("HTTP", r.status)
    print(r.read().decode())
except Exception as e:
    code = getattr(e, "code", "ERR")
    print("HTTP", code)
    try:
        print(e.read().decode())
    except Exception:
        print(e)
PY
)"

echo "$answer_out"

# ----------- RESULT INTERPRETATION -----------

if echo "$answer_out" | grep -q '"answer"'; then
  ok "OpenAI returned a real answer → E2E SUCCESS"

elif echo "$answer_out" | grep -qi "429\|quota\|rate limit"; then
  bad "OpenAI quota/rate limit hit (429) → infra OK, external quota blocking"

elif echo "$answer_out" | grep -qi "authentication\|api key"; then
  bad "Auth error → check OPENAI_API_KEY"

elif echo "$answer_out" | grep -qi "bridge"; then
  bad "Bridge unreachable from ML-GW"

else
  bad "Unexpected response — check logs"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  ok "CHATGPT E2E CHECK PASSED"
else
  bad "CHATGPT E2E CHECK FAILED"
fi

