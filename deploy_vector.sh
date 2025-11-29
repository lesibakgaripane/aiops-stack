#!/bin/bash

# --- 2. Create the COMPLETE docker-compose.vector.yml file (Inside the script) ---
cat <<'YAML_END' > docker-compose.vector.yml
services:
  vector:
    image: timberio/vector:0.35.0-alpine
    container_name: vector_shipper
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - VECTOR_HOSTS=elasticsearch:9200
      - VECTOR_INDEX_NAME=aiops-logs
    command: |
      vector --config-toml <<-VECTOR_CONFIG
      [sources.docker_logs]
        type = "docker_logs"
      [sinks.elastic_sink]
        type = "elasticsearch"
        inputs = ["docker_logs"]
        endpoint = "http://\${VECTOR_HOSTS}"
        compression = "gzip"
        index = "\${VECTOR_INDEX_NAME}"
        healthcheck.enabled = false
        batch.max_bytes = 10485760
        batch.timeout_secs = 2

      [transforms.remap_log]
        type = "remap"
        inputs = ["docker_logs"]
        source = '''
        .container_name = .docker.container_name
        .host = "aiops-vm"
        del(.docker)
        '''
      VECTOR_CONFIG
    depends_on:
      - elasticsearch
    networks:
      - aiops_network

networks:
  aiops_network:
    external: true
    name: aiops-stack_aiops-network
YAML_END

echo "--- 3. Deploying Vector Log Shipper ---"
# Use sudo to ensure Docker Compose runs correctly
sudo docker compose -f docker-compose.vector.yml up -d
