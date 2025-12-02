#!/usr/bin/env bash
set -euo pipefail

echo
echo "=============================="
echo " AIOps PORTAL BOOTSTRAP (DEV)"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="
echo

# 1) Activate a venv if present
if [ -d ".venv" ]; then
  echo "[*] Activating .venv in project root"
  # shellcheck disable=SC1091
  source .venv/bin/activate
elif [ -d "ui/ui-gateway/.venv" ]; then
  echo "[*] Activating ui/ui-gateway/.venv"
  # shellcheck disable=SC1091
  source ui/ui-gateway/.venv/bin/activate
else
  echo "[!] No venv found, using system python3"
fi

# 2) Start ui-gateway (FastAPI) on 8089
echo
echo "[1) Start ui-gateway on port 8089]"

cd "$(dirname "$0")/ui/ui-gateway"

# Load env file if present (same as run_ui_gateway.sh)
if [ -f ".env.ui-gateway" ]; then
  set -a
  source .env.ui-gateway
  set +a
fi

# Free the port just in case
sudo fuser -k 8089/tcp 2>/dev/null || true

echo "[*] Launching uvicorn app:app on 0.0.0.0:${UI_GATEWAY_PORT:-8089} in background"
python3 -m uvicorn app:app --host 0.0.0.0 --port "${UI_GATEWAY_PORT:-8089}" &

UI_GATEWAY_PID=$!
echo "[*] ui-gateway PID: ${UI_GATEWAY_PID}"
echo "[*] Sleeping 5 seconds to let it start..."
sleep 5

# 3) Run UI auth sanity check
echo
echo "[2) Run aiops_ui_auth_check.sh]"
cd ~/aiops-stack
./aiops_ui_auth_check.sh

# 4) Run portal E2E check via Nginx
echo
echo "[3) Run aiops_portal_e2e.sh]"
./aiops_portal_e2e.sh

echo
echo "=============================="
echo " Portal bootstrap completed."
echo " ui-gateway is running with PID ${UI_GATEWAY_PID}"
echo "=============================="
