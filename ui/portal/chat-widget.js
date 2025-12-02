(function(){
  const btn = document.createElement("button");
  btn.id = "lb-chat-fab";
  btn.innerText = "Chat";
  Object.assign(btn.style, {
    position: "fixed",
    right: "26px",
    bottom: "26px",
    width: "68px",
    height: "68px",
    borderRadius: "50%",
    border: "none",
    fontWeight: "600",
    fontSize: "16px",
    boxShadow: "0 10px 30px rgba(0,0,0,0.45)",
    cursor: "pointer",
    zIndex: "9999",
    backgroundImage: "linear-gradient(135deg,#7F4CFF,#FF6AD5)",
    color: "#ffffff"
  });

  const panel = document.createElement("div");
  panel.id = "lb-chat-panel";
  Object.assign(panel.style, {
    position: "fixed",
    right: "26px",
    bottom: "110px",
    width: "360px",
    maxHeight: "480px",
    padding: "16px",
    borderRadius: "18px",
    background: "rgba(8,8,16,0.96)",
    boxShadow: "0 18px 40px rgba(0,0,0,0.6)",
    color: "#f5f5ff",
    fontSize: "14px",
    display: "none",
    zIndex: "9998",
    overflow: "auto"
  });

  panel.innerHTML = `
    <div style="font-weight:600;margin-bottom:8px;">LesiBytes Cyber Assistant (MVP)</div>
    <p style="margin-top:0;margin-bottom:8px;">
      Chatbot will be wired to Rasa / AIOps stack.
      For now this is a placeholder panel.
    </p>
    <p style="margin:0;font-size:12px;opacity:0.7;">
      It will eventually answer awareness questions and show user-specific tips.
    </p>
  `;

  btn.addEventListener("click", () => {
    panel.style.display = panel.style.display === "none" ? "block" : "none";
  });

  document.body.appendChild(panel);
  document.body.appendChild(btn);
})();
