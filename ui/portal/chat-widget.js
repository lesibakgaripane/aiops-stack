// AIOps simple chat widget (UI-only, no backend yet)

(function () {
  function createChatWidget() {
    if (document.getElementById("aiops-chat-widget-root")) {
      return;
    }

    const root = document.createElement("div");
    root.id = "aiops-chat-widget-root";
    root.style.position = "fixed";
    root.style.bottom = "16px";
    root.style.right = "16px";
    root.style.zIndex = "9999";
    root.style.fontFamily = 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';

    root.innerHTML = `
      <div id="aiops-chat-panel" style="
        display: none;
        width: 320px;
        max-height: 420px;
        background: #020617;
        color: #e5e7eb;
        border-radius: 12px;
        box-shadow: 0 10px 30px rgba(0,0,0,0.7);
        border: 1px solid #1f2937;
        overflow: hidden;
        margin-bottom: 8px;
      ">
        <div style="
          padding: 8px 12px;
          background: #0f172a;
          border-bottom: 1px solid #1f2937;
          display: flex;
          align-items: center;
          justify-content: space-between;
          font-size: 13px;
        ">
          <span>AIOps Assistant (MVP)</span>
          <button id="aiops-chat-close" style="
            background: transparent;
            border: none;
            color: #9ca3af;
            cursor: pointer;
            font-size: 14px;
          ">&times;</button>
        </div>
        <div id="aiops-chat-messages" style="
          padding: 8px 12px;
          font-size: 13px;
          height: 260px;
          overflow-y: auto;
        ">
          <div style="margin-bottom: 8px; color:#9ca3af;">
            Chat is in MVP mode. Responses are local only and do not call backend yet.
          </div>
        </div>
        <form id="aiops-chat-form" style="
          display: flex;
          padding: 8px;
          border-top: 1px solid #1f2937;
          background: #020617;
        ">
          <input id="aiops-chat-input" type="text" placeholder="Ask AIOps..." style="
            flex: 1;
            padding: 6px 8px;
            border-radius: 8px;
            border: 1px solid #374151;
            background: #020617;
            color:#e5e7eb;
            font-size: 13px;
          " />
          <button type="submit" style="
            margin-left: 6px;
            padding: 6px 10px;
            border-radius: 8px;
            border: none;
            background: #38bdf8;
            color:#0f172a;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
          ">Send</button>
        </form>
      </div>

      <button id="aiops-chat-toggle" style="
        width: 56px;
        height: 56px;
        border-radius: 999px;
        border: none;
        background: #38bdf8;
        color: #0f172a;
        font-weight: 700;
        cursor: pointer;
        box-shadow: 0 10px 25px rgba(0,0,0,0.7);
        font-size: 13px;
      ">
        Chat
      </button>
    `;

    document.body.appendChild(root);

    const panel = document.getElementById("aiops-chat-panel");
    const toggleBtn = document.getElementById("aiops-chat-toggle");
    const closeBtn = document.getElementById("aiops-chat-close");
    const form = document.getElementById("aiops-chat-form");
    const input = document.getElementById("aiops-chat-input");
    const messages = document.getElementById("aiops-chat-messages");

    function addMessage(text, from) {
      const div = document.createElement("div");
      div.style.marginBottom = "6px";
      if (from === "user") {
        div.style.textAlign = "right";
        div.innerHTML = `<span style="display:inline-block;background:#1d4ed8;color:#e5e7eb;border-radius:10px;padding:4px 8px;font-size:12px;">${text}</span>`;
      } else {
        div.style.textAlign = "left";
        div.innerHTML = `<span style="display:inline-block;background:#111827;color:#e5e7eb;border-radius:10px;padding:4px 8px;font-size:12px;">${text}</span>`;
      }
      messages.appendChild(div);
      messages.scrollTop = messages.scrollHeight;
    }

    toggleBtn.addEventListener("click", function () {
      panel.style.display = panel.style.display === "none" ? "block" : "none";
    });

    closeBtn.addEventListener("click", function () {
      panel.style.display = "none";
    });

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      const text = input.value.trim();
      if (!text) return;
      addMessage(text, "user");
      input.value = "";

      setTimeout(function () {
        addMessage("This is the AIOps chat widget placeholder. Backend integration coming soon.", "bot");
      }, 300);
    });
  }

  if (document.readyState === "complete" || document.readyState === "interactive") {
    createChatWidget();
  } else {
    document.addEventListener("DOMContentLoaded", createChatWidget);
  }
})();
