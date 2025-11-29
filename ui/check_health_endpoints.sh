#!/usr/bin/env bash
set -euo pipefail

VM_IP="192.168.206.136"

echo "=== Host-facing health checks ==="
declare -A URLS=(
  ["rasa"]="http://$VM_IP:5005/status"
  ["rasa-actions"]="http://$VM_IP:5055/health"
  ["chatgpt-bridge"]="http://$VM_IP:9110/health"
  ["rag-service"]="http://$VM_IP:8000/health"
  ["anomaly-service"]="http://$VM_IP:8100/health"
  ["ml-gateway"]="http://$VM_IP:9000/health"
  ["orchestrator-docs"]="http://$VM_IP:8088/docs"
  ["heartbeat-docs"]="http://$VM_IP:8080/docs"
  ["qdrant"]="http://$VM_IP:6333/"
  ["elasticsearch"]="http://$VM_IP:9200/"
  ["kibana"]="http://$VM_IP:5601/api/status"
)

for k in "${!URLS[@]}"; do
  u="${URLS[$k]}"
  code=$(curl -s -o /dev/null -w "%{http_code}" "$u" || true)
  printf "%-20s %-4s %s\n" "$k" "$code" "$u"
done

echo
echo "=== Internal docker health checks (/health inside containers) ==="
CONTAINERS=(
  aiops-chatgpt-bridge
  aiops-ml-gateway
  aiops-rag-service
  aiops-anomaly-service
  ai_orchestrator
)

for c in "${CONTAINERS[@]}"; do
  if docker ps --format '{{.Names}}' | grep -q "^$c$"; then
    echo "--- $c"
    # Try a few common ports; if none work, print a clear note
    docker exec "$c" sh -lc '
      (curl -s http://127.0.0.1:${PORT:-8000}/health) ||
      (curl -s http://127.0.0.1:8000/health) ||
      (curl -s http://127.0.0.1:8100/health) ||
      (curl -s http://127.0.0.1:9000/health) ||
      echo "no /health on default ports"
    ' || true
  else
    echo "--- $c (NOT FOUND)"
  fi
done
