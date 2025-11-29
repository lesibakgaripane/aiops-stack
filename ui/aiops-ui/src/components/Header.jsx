import { Link } from "react-router-dom";

export default function Header() {
  return (
    <header className="bg-slate-900 border-b border-slate-800 px-5 py-3 flex items-center justify-between">
      <div className="font-bold text-lg text-slate-100">
        NetSight / UniSight AIOps
      </div>

      <nav className="flex gap-4 text-sm text-slate-300">
        <Link className="hover:text-white" to="/">Home</Link>
        <Link className="hover:text-white" to="/logs">Logs</Link>
        <Link className="hover:text-white" to="/settings">Settings</Link>
      </nav>
    </header>
  );
}
