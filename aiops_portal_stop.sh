#!/usr/bin/env bash
set -e

echo "=============================="
echo " AIOps PORTAL STOP"
echo "=============================="

# Find processes bound to port 8089
PIDS_BY_PORT=$(lsof -t -i:8089 2>/dev/null || true)

# Also match uvicorn app:app as a safety net
PIDS_BY_NAME=$(pgrep -f "uvicorn app:app" 2>/dev/null || true)

PIDS="$(echo "$PIDS_BY_PORT $PIDS_BY_NAME" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

if [ -z "$PIDS" ]; then
  echo "[*] No ui-gateway process found on port 8089."
  exit 0
fi

echo "[*] Stopping ui-gateway PIDs: $PIDS"

# First try normal kill
kill $PIDS 2>/dev/null || true
sleep 2

# If any still alive, try sudo kill, then sudo kill -9
for pid in $PIDS; do
  if kill -0 "$pid" 2>/dev/null; then
    echo "[*] PID $pid still running, trying sudo kill"
    sudo kill "$pid" 2>/dev/null || true
    sleep 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    echo "[*] PID $pid still running after sudo kill, sending sudo kill -9"
    sudo kill -9 "$pid" 2>/dev/null || true
  fi
done

echo "[*] ui-gateway stopped (or no longer bound to 8089)."
