#!/usr/bin/env bash

set -euo pipefail

PORTAL_URL="${PORTAL_URL:-http://localhost}"
UI_GATEWAY_URL="${UI_GATEWAY_URL:-http://localhost:8089}"

echo
echo "=============================="
echo " AIOps PORTAL E2E Sanity Check"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="
echo

########################################
# 1) Portal landing page via Nginx (/)
########################################
echo "[1) Portal landing page via Nginx (/)]"

HTTP_CODE=$(curl -s -o /tmp/aiops_portal_landing.html -w "%{http_code}" "$PORTAL_URL/")
echo "HTTP $HTTP_CODE"

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Landing page HTTP code not 200"
  exit 1
fi

if grep -q "AIOps Unified Portal" /tmp/aiops_portal_landing.html; then
  echo "✓ Found 'AIOps Unified Portal' in landing page"
else
  echo "❌ Could not find 'AIOps Unified Portal' in landing page"
  exit 1
fi

echo

##############################################
# 2) /status/ecosystem/status via Nginx
##############################################
echo "[2) /status/ecosystem/status via Nginx]"

STATUS_JSON=$(curl -s "$PORTAL_URL/status/ecosystem/status")
echo "RAW:"
echo "$STATUS_JSON"
echo

###############################################################
# 3) Auth login via /api/auth/login (admin/password)
#    (Calls ui-gateway directly on port 8089)
###############################################################
echo "[3) Auth login via /api/auth/login (admin/password)]"

LOGIN_JSON=$(curl -s -X POST "$UI_GATEWAY_URL/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=password")

echo "RAW:"
echo "$LOGIN_JSON"

TOKEN_TYPE=$(printf '%s\n' "$LOGIN_JSON" | sed -n 's/.*"token_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
ACCESS_TOKEN=$(printf '%s\n' "$LOGIN_JSON" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

echo "Parsed:"
echo "  token_type: ${TOKEN_TYPE:-}"
if [ -n "$ACCESS_TOKEN" ]; then
  FIRST20=$(printf '%s' "$ACCESS_TOKEN" | cut -c1-20)
  echo "  token (first 20 chars): ${FIRST20}..."
else
  echo "  token (first 20 chars): ..."
fi

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Login failed (no access_token). Stopping check."
  exit 1
fi

echo "✓ Login succeeded and access_token received."
