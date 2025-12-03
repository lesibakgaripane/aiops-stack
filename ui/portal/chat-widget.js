(function() {
  // Do NOT show chat on login or index
  const path = window.location.pathname;
  if (path.endsWith("/login.html") || path.endsWith("/index.html")) {
    return;
  }

  // Inject simple keyframes for pulse animation
  const styleEl = document.createElement("style");
  styleEl.innerHTML = `
  @keyframes lb-pulse {
    0%   { transform: scale(1);   box-shadow: 0 0 0 0 rgba(127,76,255,0.8); }
    100% { transform: scale(1.08); box-shadow: 0 0 0 14px rgba(127,76,255,0); }
  }`;
  document.head.appendChild(styleEl);

  const btn = document.createElement("button");
  btn.id = "lb-chat-fab";
  btn.innerText = "Chat";

  Object.assign(btn.style, {
    position: "fixed",
    right: "26px",
    bottom: "26px",
    width: "80px",
    height: "80px",
    borderRadius: "50%",
    border: "none",
    fontWeight: "600",
    fontSize: "16px",
    boxShadow: "0 14px 40px rgba(0,0,0,0.75)",
    cursor: "pointer",
    zIndex: "9999",
    backgroundImage: "linear-gradient(135deg,#7F4CFF,#FF6AD5)",
    color: "#ffffff",
    animation: "lb-pulse 1.8s infinite alternate"
  });

  const panel = document.createElement("div");
  panel.id = "lb-chat-panel";
  Object.assign(panel.style, {
    position: "fixed",
    right: "26px",
    bottom: "120px",
    width: "360px",
    maxHeight: "480px",
    padding: "16px",
    borderRadius: "18px",
    background: "rgba(8,8,16,0.96)",
    boxShadow: "0 18px 40px rgba(0,0,0,0.8)",
    color: "#f5f5ff",
    display: "none",
    flexDirection: "column",
    zIndex: "9998",
    border: "1px solid rgba(255,255,255,0.12)"
  });

  panel.innerHTML = `
    <div style="font-weight:600;margin-bottom:6px;">LesiBot Assistant</div>
    <div id="lb-chat-log" style="flex:1;overflow:auto;font-size:13px;margin-bottom:8px;padding-right:4px;"></div>
    <div style="display:flex;gap:6px;">
      <input id="lb-chat-input" type="text" placeholder="Ask anything about AIOps or awareness..."
        style="flex:1;padding:8px;border-radius:10px;border:none;background:rgba(0,0,0,0.65);color:#fff;">
      <button id="lb-chat-send" style="padding:8px 14px;border-radius:999px;border:none;background:#7F4CFF;color:#fff;font-weight:600;cursor:pointer;">Send</button>
    </div>
  `;

  function appendMessage(sender, text) {
    const log = document.getElementById("lb-chat-log");
    const row = document.createElement("div");
    row.style.marginBottom = "6px";
    row.innerHTML = `<b>${sender}:</b> ${text}`;
    log.appendChild(row);
    log.scrollTop = log.scrollHeight;
  }

  function sendMessage() {
    const input = document.getElementById("lb-chat-input");
    const msg = (input.value || "").trim();
    if (!msg) return;

    appendMessage("You", msg);
    input.value = "";

    fetch("/ui-api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message: msg })
    })
      .then(r => r.json())
      .then(data => {
        appendMessage("LesiBot", data.reply || "(no reply)");
      })
      .catch(() => {
        appendMessage("LesiBot", "I could not reach the AIOps brain right now.");
      });
  }

  btn.addEventListener("click", () => {
    panel.style.display = (panel.style.display === "none" ? "flex" : "none");
  });

  panel.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      sendMessage();
    }
  });

  panel.querySelector("#lb-chat-send").addEventListener("click", sendMessage);

  document.body.appendChild(panel);
  document.body.appendChild(btn);
})();
