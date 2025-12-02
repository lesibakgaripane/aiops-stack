// Simple AIOps Portal auth helper (localStorage-based)

const AIOPS_AUTH_KEY = "aiops_auth";

function aiopsSaveAuth(data) {
  try {
    localStorage.setItem(AIOPS_AUTH_KEY, JSON.stringify(data));
  } catch (e) {
    console.error("Failed to save auth:", e);
  }
}

function aiopsGetAuth() {
  try {
    const raw = localStorage.getItem(AIOPS_AUTH_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (e) {
    console.error("Failed to parse auth:", e);
    return null;
  }
}

function aiopsClearAuth() {
  try {
    localStorage.removeItem(AIOPS_AUTH_KEY);
  } catch (e) {
    console.error("Failed to clear auth:", e);
  }
}

function aiopsIsLoggedIn() {
  const auth = aiopsGetAuth();
  return !!(auth && auth.access_token);
}

function aiopsGetAuthHeader() {
  const auth = aiopsGetAuth();
  if (!auth || !auth.access_token) return {};
  return { Authorization: "Bearer " + auth.access_token };
}

function aiopsRequireAuth(redirectTo) {
  if (!aiopsIsLoggedIn()) {
    window.location.href = redirectTo;
  }
}

// Expose as global object
window.aiopsAuth = {
  saveAuth: aiopsSaveAuth,
  getAuth: aiopsGetAuth,
  clearAuth: aiopsClearAuth,
  isLoggedIn: aiopsIsLoggedIn,
  getAuthHeader: aiopsGetAuthHeader,
  requireAuth: aiopsRequireAuth,
};


// --- hide debug 'Current user (via /api/auth/me)' block if present ---
document.addEventListener("DOMContentLoaded", () => {
  try {
    const marker = "Current user (via /api/auth/me)";
    const nodes = document.querySelectorAll("body *");
    nodes.forEach((el) => {
      if (el.textContent && el.textContent.includes(marker)) {
        const container = el.closest("section,div,article") || el;
        container.style.display = "none";
      }
    });
  } catch (e) {
    console.error("Failed to hide debug block:", e);
  }
});
