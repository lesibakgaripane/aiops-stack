#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

# Activate local venv if present
if [ -d ".venv" ]; then
  source .venv/bin/activate
fi

# Load env file if present
if [ -f ".env.ui-gateway" ]; then
  set -a
  source .env.ui-gateway
  set +a
fi

# Free port 8089 if something is listening
sudo fuser -k 8089/tcp 2>/dev/null || true

# Start uvicorn
python3 -m uvicorn app:app --host 0.0.0.0 --port "${UI_GATEWAY_PORT:-8089}"
