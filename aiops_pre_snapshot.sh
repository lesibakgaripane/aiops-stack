#!/usr/bin/env bash
set -e

echo "=============================="
echo " AIOps PRE-SNAPSHOT CHECK"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="

cd ~/aiops-stack

echo
echo "[1] Running baseline E2E sanity (aiops_e2e_sanity_v3.sh)..."
./aiops_e2e_sanity_v3.sh

echo
echo "Baseline sanity PASSED. All required containers and core ports are healthy."

echo
echo "[2] Running Git backup..."
./aiops_git_backup.sh "Pre-snapshot backup $(date '+%F %H:%M:%S')"

echo
echo "✅ Pre-snapshot checklist complete."
echo "👉 You can now safely take a VM snapshot in your hypervisor with this note:"
echo "   'AIOps baseline – all services green, pre-snapshot script run successfully.'"
