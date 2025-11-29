import { BrowserRouter, Routes, Route } from "react-router-dom";
import Header from "./components/Header";
import ChatDock from "./components/ChatDock";
import HomeDashboard from "./pages/HomeDashboard";
import Logs from "./pages/Logs";
import Settings from "./pages/Settings";

export default function App() {
  return (
    <BrowserRouter>
      <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
        <Header />

        {/* Bottom padding prevents content hiding behind dock */}
        <main className="flex-1 pb-28">
          <Routes>
            <Route path="/" element={<HomeDashboard />} />
            <Route path="/logs" element={<Logs />} />
            <Route path="/settings" element={<Settings />} />
          </Routes>
        </main>

        <ChatDock />
      </div>
    </BrowserRouter>
  );
}
