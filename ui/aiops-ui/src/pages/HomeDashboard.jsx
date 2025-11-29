import { useEffect, useState } from "react";
const GATEWAY = import.meta.env.VITE_GATEWAY_URL || "/api";

export default function HomeDashboard() {
  const [items, setItems] = useState([]);
  const [err, setErr] = useState(null);

  useEffect(() => {
    fetch(`${GATEWAY}/ecosystem/inventory`)
      .then(r => r.json())
      .then(setItems)
      .catch(e => setErr(e.message));
  }, []);

  return (
    <div className="p-5 space-y-4">
      <h1 className="text-2xl font-bold">AIOps Ecosystem — Inventory</h1>
      <p className="text-slate-400 text-sm">
        Live view of services, roles, images, ports, and Docker IPs.
      </p>

      {err && (
        <div className="bg-red-900/40 border border-red-700 p-3 rounded-xl">
          Error loading inventory: {err}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
        {items.map((it, idx) => (
          <div key={idx} className="bg-slate-900 border border-slate-800 rounded-2xl p-4 shadow">
            <div className="flex items-center justify-between">
              <div className="font-semibold">{it.container}</div>
              <div className={`text-xs px-2 py-1 rounded-full ${
                it.state === "Up" ? "bg-green-700/40 text-green-200" : "bg-red-700/40 text-red-200"
              }`}>
                {it.state}
              </div>
            </div>

            <div className="mt-2 text-xs text-slate-400 break-words space-y-1">
              <div><span className="text-slate-300">Image:</span> {it.image}</div>
              <div><span className="text-slate-300">Host ports:</span> {it.host_ports || "-"}</div>
              <div><span className="text-slate-300">Docker IPs:</span> {it.docker_ips || "-"}</div>
              <div><span className="text-slate-300">Function:</span> {it.function}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
