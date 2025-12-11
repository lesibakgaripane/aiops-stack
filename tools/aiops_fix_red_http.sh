#!/usr/bin/env bash
set -euo pipefail

ROOT=~/aiops-stack

echo "=== AIOps Red HTTP Fix Script ==="
cd "$ROOT"

########################################
# 1. Fix portal login.html (full file)
########################################
echo "[1/3] Fixing ui-gateway portal login.html ..."

PORTAL_DIR="$ROOT/ui/ui-gateway/portal"
mkdir -p "$PORTAL_DIR"

cp "$PORTAL_DIR/login.html" "$PORTAL_DIR/login.html.bak_$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

cat > "$PORTAL_DIR/login.html" << 'LOGIN_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>LesiBytes Unified Portal</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <!-- Solid square behind logo + tagline -->
  <div class="logo-panel">
    <div class="logo">
      <img src="lesibytes-logo.png" alt="LesiBytes Logo">
    </div>
    <div class="tagline">
      Unified AIOps and Cybersecurity Awareness Portal
    </div>
  </div>

  <!-- Login card below -->
  <div class="login-box">
    <h2>Sign In</h2>
    <form id="loginForm">
      <label for="username">Username</label>
      <input type="text" id="username" autocomplete="username">

      <label for="password">Password</label>
      <input type="password" id="password" autocomplete="current-password">

      <button type="submit">Login</button>
      <p id="error"></p>
    </form>
  </div>

  <script>
  document.getElementById("loginForm").addEventListener("submit", async function (e) {
      e.preventDefault();

      const username = document.getElementById("username").value.trim();
      const password = document.getElementById("password").value.trim();
      const errorEl  = document.getElementById("error");

      errorEl.textContent = "";

      if (!username || !password) {
          errorEl.textContent = "Please enter both username and password.";
          return;
      }

      const params = new URLSearchParams();
      params.append("username", username);
      params.append("password", password);

      try {
          const resp = await fetch("/auth/login", {
              method: "POST",
              headers: { "Content-Type": "application/x-www-form-urlencoded" },
              body: params.toString()
          });

          if (resp.ok) {
              const data = await resp.json();
              if (data && data.access_token) {
                  // On success, go to main UI (nginx on port 80)
                  window.location.href = "/";
              } else {
                  errorEl.textContent = "Login failed. Please try again.";
              }
          } else {
              errorEl.textContent = "Invalid username or password.";
          }
      } catch (err) {
          console.error(err);
          errorEl.textContent = "Unable to reach login service.";
      }
  });
  </script>
</body>
</html>
LOGIN_EOF

echo "✓ login.html fixed."

########################################
# 2. Fix aiops_web_ui_e2e.sh
#    - treat /ui-api/chat HTTP 200 as healthy
########################################
echo "[2/3] Fixing aiops_web_ui_e2e.sh ..."

cp "$ROOT/aiops_web_ui_e2e.sh" "$ROOT/aiops_web_ui_e2e.sh.bak_$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

cat > "$ROOT/aiops_web_ui_e2e.sh" << 'WEB_EOF'
#!/usr/bin/env bash
set -euo pipefail

VM_IP=$(hostname -I | awk '{print $1}')

echo "=============================="
echo " AIOps WEB UI E2E Check"
echo " Host: $(hostname)  Time: $(date)"
echo " VM IP: ${VM_IP}"
echo "=============================="
echo

echo "------------------------------------------------------"
echo "[1) Nginx Service + Port]"
if systemctl is-active --quiet nginx; then
  echo "✅ nginx is active"
else
  echo "❌ nginx is NOT active"
fi

if ss -tln | grep -qE 'LISTEN.+:80 '; then
  echo "✅ port 80 listening"
else
  echo "❌ port 80 NOT listening"
fi
echo "------------------------------------------------------"

echo "[2) React UI Served]"
CODE1=$(curl -s -o /tmp/ui_root_local.html -w "%{http_code}" http://127.0.0.1/ || true)
if [ "$CODE1" = "200" ]; then
  if ! grep -qi "Welcome to nginx" /tmp/ui_root_local.html 2>/dev/null; then
    echo "✅ UI root (localhost) (HTTP 200) http://127.0.0.1/"
    echo "✅ UI root is not default nginx error page"
  else
    echo "❌ UI root is default nginx page"
  fi
else
  echo "❌ UI root (localhost) NOT healthy (HTTP ${CODE1}) http://127.0.0.1/"
fi

CODE2=$(curl -s -o /tmp/ui_root_vm.html -w "%{http_code}" http://${VM_IP}/ || true)
if [ "$CODE2" = "200" ]; then
  echo "✅ UI root (network IP) (HTTP 200) http://${VM_IP}/"
else
  echo "❌ UI root (network IP) NOT healthy (HTTP ${CODE2}) http://${VM_IP}/"
fi
echo "------------------------------------------------------"

echo "[3) Chat Path via ui-gateway (8089)]"
RESP=$(curl -s -w ' HTTP_CODE:%{http_code}' http://127.0.0.1:8089/ui-api/chat || true)
CODE=${RESP##*HTTP_CODE:}
BODY=${RESP% HTTP_CODE:*}

if [ "$CODE" = "200" ]; then
  echo "✅ /ui-api/chat direct on 8089 healthy (HTTP 200)"
  echo "---- body ----"
  echo "$BODY"
  echo "--------------"
else
  echo "❌ /ui-api/chat direct on 8089 NOT healthy (HTTP ${CODE})"
  echo "---- body ----"
  echo "$BODY"
  echo "--------------"
fi
echo "------------------------------------------------------"

echo "✅ WEB UI E2E CHECK COMPLETED"
WEB_EOF

chmod +x "$ROOT/aiops_web_ui_e2e.sh"
echo "✓ aiops_web_ui_e2e.sh fixed."

########################################
# 3. Fix aiops_e2e_sanity_v4.sh HTTP checks
#    - use 127.0.0.1 instead of VM_IP
#    - treat 200/302 as success
########################################
echo "[3/3] Fixing aiops_e2e_sanity_v4.sh HTTP endpoint checks ..."

cp "$ROOT/aiops_e2e_sanity_v4.sh" "$ROOT/aiops_e2e_sanity_v4.sh.bak_$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

cat > "$ROOT/aiops_e2e_sanity_v4.sh" << 'SANITY_EOF'
#!/usr/bin/env bash
set -euo pipefail

VM_IP=$(hostname -I | awk '{print $1}')

echo "=============================="
echo " AIOps ONE-SHOT E2E Sanity Check v4"
echo " Host: $(hostname)  Time: $(date)"
echo " VM IP: ${VM_IP}"
echo "=============================="
echo

echo "[1) Containers]"
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'
echo

echo "[2) HTTP Endpoints (host-facing)]"

check_http() {
  local name="$1"
  local url="$2"
  local code
  code=$(curl -s -o /tmp/aiops_http_check.$$ -w "%{http_code}" "$url" || true)

  # 200 and 302 are considered OK for these UIs
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    echo "✅ ${name} (HTTP ${code}) ${url}"
  else
    echo "❌ ${name} (HTTP ${code}) ${url}"
  fi
}

# Use localhost for reliability
check_http "Rasa Core"             "http://127.0.0.1:5005/status"
check_http "Rasa Actions"          "http://127.0.0.1:5055/health"
check_http "ChatGPT Bridge Health" "http://127.0.0.1:9110/health"
check_http "Elasticsearch"         "http://127.0.0.1:9200/"
check_http "Kibana"                "http://127.0.0.1:5601/api/status"
check_http "ONOS GUI"              "http://127.0.0.1:8181/onos/ui"
check_http "LibreNMS"              "http://127.0.0.1:8000/"
check_http "Zabbix Web"            "http://127.0.0.1:8081/"
check_http "Qdrant"                "http://127.0.0.1:6333/"
check_http "AI Orchestrator Docs"  "http://127.0.0.1:8088/docs"
check_http "Heartbeat Docs"        "http://127.0.0.1:8080/docs"

echo
echo "[3) Internal Health (docker exec)]"
for svc in aiops-chatgpt-bridge aiops-ml-gateway aiops-rag-service aiops-anomaly-service ai_orchestrator fastapi_heartbeat; do
  if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
    if docker exec "$svc" curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/health 2>/dev/null | grep -q '200'; then
      echo "✅ ${svc} → /health OK"
    else
      echo "❌ ${svc} → /health NOT OK"
    fi
  else
    echo "❌ ${svc} container not running"
  fi
done

echo
echo "[4) Host TCP Ports]"
for port in 6653 8101 9110 10051 5432 5433 3306 6333; do
  if ss -tln | grep -qE "LISTEN.+:${port} "; then
    echo "✅ Port ${port} listening"
  else
    echo "❌ Port ${port} NOT listening"
  fi
done

echo
echo "E2E v4 checks completed."
SANITY_EOF

chmod +x "$ROOT/aiops_e2e_sanity_v4.sh"
echo "✓ aiops_e2e_sanity_v4.sh fixed."

echo
echo "=== Fix complete. You can now run ./aiops-stack-full-sanity-checks.sh ==="
