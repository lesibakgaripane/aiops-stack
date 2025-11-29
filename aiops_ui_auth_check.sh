#!/usr/bin/env bash
set -euo pipefail

BASE_DIRECT="http://127.0.0.1:8089"
BASE_NGINX="http://127.0.0.1/api"

echo
echo "=============================="
echo " AIOps UI AUTH E2E Check"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="
echo

is_json() {
  local first
  first=$(printf '%s' "$1" | sed 's/^[[:space:]]*//' | head -c1)
  [[ "$first" == "{" || "$first" == "[" ]]
}

echo "[1) /health direct]"
curl -s "$BASE_DIRECT/health"
echo
echo

echo "[2) /auth/login direct (admin)]"
RESP=$(curl -s -X POST "$BASE_DIRECT/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=password")
echo "RAW:"
echo "$RESP"
if is_json "$RESP"; then
  echo "JSON:"
  echo "$RESP" | jq
fi
echo

echo "[3) /auth/login via Nginx (admin)]"
RESP=$(curl -s -X POST "$BASE_NGINX/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=password")
echo "RAW:"
echo "$RESP"
if is_json "$RESP"; then
  echo "JSON:"
  echo "$RESP" | jq
fi
echo

echo "====== END AIOps UI AUTH E2E Check ======"
