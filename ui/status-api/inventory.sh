#!/usr/bin/env bash
set -euo pipefail

# inventory in JSON using docker inspect
docker ps --format '{{.Names}}' | while read -r name; do
  img=$(docker inspect -f '{{.Config.Image}}' "$name")
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name")
  ports=$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$name")
  os=$(docker inspect -f '{{.Config.Labels.org.opencontainers.image.base.name}}' "$name" 2>/dev/null || echo "unknown")

  echo "{\"name\":\"$name\",\"image\":\"$img\",\"container_os\":\"$os\",\"docker_ip\":\"$ip\",\"ports\":$ports}"
done | jq -s '{services: .}'
