import { useEffect, useRef, useState } from "react";

const GATEWAY = import.meta.env.VITE_GATEWAY_URL || "/api";

export default function ChatDock() {
  const [open, setOpen] = useState(true);
  const [mode, setMode] = useState("local_only");
  const [messages, setMessages] = useState([
    { role: "bot", text: "Hi! I’m NetSight. Ask me anything about your AIOps ecosystem." }
  ]);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const scrollRef = useRef(null);

  useEffect(() => {
    if (open && scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, open]);

  async function send() {
    const q = input.trim();
    if (!q || busy) return;

    setMessages(m => [...m, { role: "user", text: q }]);
    setInput("");
    setBusy(true);

    try {
      const res = await fetch(`${GATEWAY}/chat/send`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: q, mode })
      });

      const data = await res.json();
      const topHit =
        data?.hits?.[0]?.text ||
        data?.answer ||
        data?.error ||
        "No answer yet.";

      setMessages(m => [...m, { role: "bot", text: topHit }]);
    } catch (e) {
      setMessages(m => [...m, { role: "bot", text: `Error: ${e.message}` }]);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50">
      {/* Dock header bar */}
      <div
        className="bg-slate-900 border-t border-slate-700 px-4 py-2 flex items-center justify-between cursor-pointer"
        onClick={() => setOpen(o => !o)}
      >
        <div className="font-semibold">
          💬 NetSight Chat
          <span className="ml-2 text-xs text-slate-400">(always available)</span>
        </div>
        <div className="text-sm text-slate-300">
          {open ? "▼ collapse" : "▲ expand"}
        </div>
      </div>

      {/* Expandable chat body */}
      {open && (
        <div className="bg-slate-950 border-t border-slate-800 shadow-2xl">
          <div ref={scrollRef} className="h-64 overflow-y-auto px-4 py-3 space-y-2">
            {messages.map((m, i) => (
              <div
                key={i}
                className={`max-w-[85%] px-3 py-2 rounded-2xl text-sm ${
                  m.role === "user"
                    ? "ml-auto bg-blue-600 text-white"
                    : "mr-auto bg-slate-800 text-slate-100"
                }`}
              >
                {m.text}
              </div>
            ))}

            {busy && (
              <div className="mr-auto bg-slate-800 px-3 py-2 rounded-2xl text-sm text-slate-100">
                Thinking…
              </div>
            )}
          </div>

          <div className="px-3 py-2 border-t border-slate-800 flex items-center gap-2">
            <select
              className="bg-slate-900 border border-slate-700 rounded-lg px-2 py-1 text-xs"
              value={mode}
              onChange={(e) => setMode(e.target.value)}
              title="Routing mode"
            >
              <option value="local_only">Local only</option>
              <option value="hybrid">Hybrid (fallback)</option>
              <option value="chatgpt_only">ChatGPT only</option>
            </select>

            <input
              className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-sm outline-none"
              placeholder="Type your question…"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && send()}
            />

            <button
              onClick={send}
              disabled={busy}
              className="bg-green-600 hover:bg-green-500 disabled:opacity-50 px-4 py-2 rounded-xl text-sm font-semibold"
            >
              Send
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
