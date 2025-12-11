#!/usr/bin/env bash
set -euo pipefail

# ======================================================
# AIOps WEB UI END-TO-END CHECK (READ-ONLY)
# - NO restarts, NO builds, NO changes
# - Validates nginx -> React UI -> /api proxy -> ui-gateway -> backend
# ======================================================

TS="$(date)"
HOST="$(hostname)"
VM_IP="$(hostname -I | awk '{print $1}')"
FAIL=0

UI_URL_DEFAULT="http://127.0.0.1/"
UI_URL_NET="http://${VM_IP}/"
API_BASE="http://127.0.0.1/api"
GATEWAY_DIRECT="http://127.0.0.1:8089"
STATUS_DIRECT="http://127.0.0.1:8090"

line() { printf "%s\n" "------------------------------------------------------"; }
ok()   { printf "\033[0;32m✅ %s\033[0m\n" "$*"; }
bad()  { printf "\033[0;31m❌ %s\033[0m\n" "$*"; FAIL=1; }

header() {
cat <<HDR

==============================
 AIOps WEB UI E2E Check
 Host: ${HOST}  Time: ${TS}
 VM IP: ${VM_IP}
==============================

HDR
}

# ---- helper for HTTP checks
check_http_code() {
  local url="$1" expect="$2" name="$3"
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || echo 000)"
  if [[ "$code" == "$expect" ]]; then ok "$name (HTTP $code) $url"
  else bad "$name expected $expect got $code $url"
  fi
}

check_http_json() {
  local url="$1" name="$2"
  local out
  out="$(curl -s --max-time 8 "$url" || true)"
  if echo "$out" | jq -e . >/dev/null 2>&1 ; then ok "$name returned JSON"
  else bad "$name did not return JSON: $url"
       echo "---- body ----"
       echo "$out" | head -n 20
       echo "--------------"
  fi
}

header

# ======================================================
# [1) Nginx Service + Port]
# ======================================================
line
echo "[1) Nginx Service + Port]"
if systemctl is-active --quiet nginx; then ok "nginx is active"
else bad "nginx is NOT active"
fi

if ss -lntp | grep -q ':80 '; then ok "port 80 listening"
else bad "port 80 NOT listening"
fi

# ======================================================
# [2) React UI Served]
#   - We want 200 and not default 404 page.
# ======================================================
line
echo "[2) React UI Served]"

# Check localhost root returns 200
check_http_code "$UI_URL_DEFAULT" "200" "UI root (localhost)"

# Make sure it's not the nginx default 404 page
body="$(curl -s --max-time 5 "$UI_URL_DEFAULT" | head -n 5 || true)"
if echo "$body" | grep -qi "502 Bad Gateway\|404 Not Found"; then
  bad "UI root looks like nginx error page"
  echo "$body"
else
  ok "UI root is not default nginx error page"
fi

# Optional network IP check
check_http_code "$UI_URL_NET" "200" "UI root (network IP)"

# ======================================================
# [3) Direct Backend Health (clarity checks)]
# ======================================================
line
echo "[3) Direct Backend Health]"

check_http_json "${GATEWAY_DIRECT}/health" "ui-gateway /health direct"
check_http_json "${STATUS_DIRECT}/ecosystem/status" "status-api /ecosystem/status direct"

# ======================================================
# [4) Nginx -> Gateway -> Status]
# ======================================================
line
echo "[4) Nginx Proxy Status Path]"
check_http_json "${API_BASE}/status" "/api/status via nginx"

# ======================================================
# [5) Nginx -> Gateway -> Chat]
#   Use local_only to avoid OpenAI quota.
# ======================================================
line
echo "[5) Nginx Proxy Chat Path]"
chat_out="$(curl -s --max-time 20 -X POST "${API_BASE}/chat/send" \
  -H "Content-Type: application/json" \
  -d '{"message":"hello from webui check","mode":"local_only"}' || true)"

if echo "$chat_out" | jq -e '.ok == true' >/dev/null 2>&1 ; then
  ok "/api/chat/send via nginx returned ok:true"
else
  bad "/api/chat/send via nginx not healthy"
  echo "---- body ----"
  echo "$chat_out" | head -n 40
  echo "--------------"
fi

# ======================================================
# Final
# ======================================================
line
if [[ "$FAIL" -eq 0 ]]; then
  ok "WEB UI E2E CHECK PASSED (all green)"
  exit 0
else
  bad "WEB UI E2E CHECK FAILED"
  exit 1
fi
