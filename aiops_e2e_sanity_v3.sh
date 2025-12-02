#!/usr/bin/env bash
set -e

echo "=============================="
echo " AIOps ONE-SHOT E2E Sanity Check v3 (baseline)"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="

VM_IP=$(hostname -I | awk '{print $1}')
echo " VM IP: ${VM_IP}"

echo
echo "[1) Containers]"
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | sort

CRIT_FAIL=0

check_container () {
  local name="$1"
  if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
    echo "✅ ${name} (running)"
  else
    echo "❌ ${name} (NOT running)"
    CRIT_FAIL=1
  fi
}

# Core AIOps services
check_container aiops-rasa
check_container aiops-rasa-actions
check_container aiops-rag-service
check_container aiops-ml-gateway
check_container aiops-anomaly-service
check_container aiops-rag-db
check_container ai_orchestrator
check_container ai_pgvector
check_container datalake_db
check_container fastapi_heartbeat

# Monitoring / telemetry
check_container prometheus
check_container node_exporter
check_container fluent_bit_shipper
check_container elasticsearch
check_container kibana
check_container onos
check_container onos_collector
check_container librenms-clean
check_container librenms-db
check_container zabbix-web
check_container zabbix-server
check_container mariadb

echo
echo "[2) Host TCP Ports (critical core ports)]"

check_port () {
  local desc="$1"
  local port="$2"
  if ss -lnt | awk '{print $4}' | grep -q ":${port}$"; then
    echo "✅ ${desc} open (:${port})"
  else
    echo "❌ ${desc} CLOSED (:${port})"
    CRIT_FAIL=1
  fi
}

check_port "ONOS OpenFlow"       6653
check_port "ONOS SSH"            8101
check_port "Zabbix Server"       10051
check_port "Postgres datalake"   5432
check_port "Postgres pgvector"   5433
check_port "MariaDB"             3306
check_port "Qdrant HTTP"         6333

echo
if [ "$CRIT_FAIL" -eq 0 ]; then
  echo "✅ SANITY CHECK PASSED (baseline)."
  echo "   All required containers and critical ports are healthy."
else
  echo "❌ SANITY CHECK FAILED — see items marked ❌ above."
fi
