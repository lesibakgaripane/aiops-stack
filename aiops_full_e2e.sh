#!/usr/bin/env bash
set -e

echo "=============================="
echo " AIOps FULL E2E Sanity"
echo " Host: $(hostname)  Time: $(date)"
echo "=============================="

# 1) Container / core stack sanity (if script exists)
if [ -x "./aiops_e2e_sanity_v3.sh" ]; then
  echo "[1] Running aiops_e2e_sanity_v3.sh ..."
  ./aiops_e2e_sanity_v3.sh
else
  echo "[1] Skipping aiops_e2e_sanity_v3.sh (not found or not executable)"
fi

# 2) UI-gateway / auth sanity
if [ -x "./aiops_ui_auth_check.sh" ]; then
  echo
  echo "[2] Running aiops_ui_auth_check.sh ..."
  ./aiops_ui_auth_check.sh
else
  echo "[2] Skipping aiops_ui_auth_check.sh (not found or not executable)"
fi

# 3) Portal / Nginx E2E sanity
if [ -x "./aiops_portal_e2e.sh" ]; then
  echo
  echo "[3] Running aiops_portal_e2e.sh ..."
  ./aiops_portal_e2e.sh
else
  echo "[3] Skipping aiops_portal_e2e.sh (not found or not executable)"
fi

echo
echo "=============================="
echo " AIOps FULL E2E Completed"
echo "=============================="
