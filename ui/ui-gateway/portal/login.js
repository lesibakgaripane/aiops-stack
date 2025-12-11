document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("loginForm");
  const errorEl = document.getElementById("error");

  function mapRoleToGroup(username, backendRole) {
    const u = (username || "").toLowerCase();
    const r = (backendRole || "").toLowerCase();

    // Hard mapping for you
    if (u === "lesiba") return "Super-Admin";       // your main account
    if (u === "superadmin" || r === "super-admin") return "Super-Admin";
    if (u === "admin" || r === "admin")            return "Admin";
    if (u === "superuser" || r === "super-user")   return "Super-User";

    // Default for everyone else
    return "End-User";
  }

  function redirectForGroup(group) {
    switch (group) {
      case "Super-Admin":
        window.location.href = "/portal/superadmin.html";
        break;
      case "Admin":
        window.location.href = "/portal/admin.html";
        break;
      case "Super-User":
        window.location.href = "/portal/superuser.html";
        break;
      default:
        window.location.href = "/portal/enduser.html";
        break;
    }
  }

  async function doLogin(username, password) {
    try {
      errorEl.textContent = "";

      const resp = await fetch("/api/auth/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ username, password })
      });

      if (!resp.ok) {
        const txt = await resp.text();
        console.error("Login failed:", resp.status, txt);
        throw new Error("Login failed");
      }

      const data = await resp.json();
      const role = data.role || "user";

      const group = mapRoleToGroup(username, role);

      // Persist auth + role info in localStorage
      localStorage.setItem("aiops_token", data.access_token);
      localStorage.setItem("aiops_username", data.username || username);
      localStorage.setItem("aiops_role", role);
      localStorage.setItem("aiops_group", group);

      // Redirect based on group
      redirectForGroup(group);
    } catch (err) {
      console.error("Login error", err);
      errorEl.textContent = "Login failed. Please check your username/password.";
    }
  }

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const username = document.getElementById("username").value.trim();
    const password = document.getElementById("password").value;

    if (!username || !password) {
      errorEl.textContent = "Username and password are required.";
      return;
    }

    doLogin(username, password);
  });
});
