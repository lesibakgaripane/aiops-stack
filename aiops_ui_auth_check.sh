#!/usr/bin/env bash
set -euo pipefail

UI_GATEWAY_URL="${UI_GATEWAY_URL:-http://localhost:8089}"
USERNAME="${USERNAME:-admin}"
PASSWORD="${PASSWORD:-password}"

echo
echo "=============================="
echo " AIOps UI Auth Sanity Check"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="
echo
echo "[1) Login via ${UI_GATEWAY_URL}/auth/login]"

LOGIN_JSON=$(curl -s -w '\n%{http_code}' -X POST "${UI_GATEWAY_URL}/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${USERNAME}&password=${PASSWORD}")

LOGIN_BODY=$(printf '%s\n' "$LOGIN_JSON" | sed '$d')
LOGIN_CODE=$(printf '%s\n' "$LOGIN_JSON" | tail -n1)

echo "HTTP ${LOGIN_CODE}"
echo "RAW:"
echo "${LOGIN_BODY}"

if [ "${LOGIN_CODE}" != "200" ]; then
  echo "❌ Login failed (HTTP ${LOGIN_CODE})"
  exit 1
fi

TOKEN=$(printf '%s\n' "${LOGIN_BODY}" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "${TOKEN}" ]; then
  echo "❌ No access_token found in login response"
  exit 1
fi

echo "Parsed:"
echo "  token (first 20 chars): ${TOKEN:0:20}..."

echo
echo "[2) /api/auth/me with Bearer token]"

ME_JSON=$(curl -s -w '\n%{http_code}' "${UI_GATEWAY_URL}/api/auth/me" \
  -H "Authorization: Bearer ${TOKEN}")

ME_BODY=$(printf '%s\n' "$ME_JSON" | sed '$d')
ME_CODE=$(printf '%s\n' "$ME_JSON" | tail -n1)

echo "HTTP ${ME_CODE}"
echo "RAW:"
echo "${ME_BODY}"

if [ "${ME_CODE}" != "200" ]; then
  echo "❌ /api/auth/me failed (HTTP ${ME_CODE})"
  exit 1
fi

echo
echo "✓ UI auth sanity check PASSED (login + /api/auth/me)"
