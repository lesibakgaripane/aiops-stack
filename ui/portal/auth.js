async function lbLogin() {
  const user = document.getElementById("lb-username").value.trim();
  const pass = document.getElementById("lb-password").value.trim();

  if (!user || !pass) {
    alert("Please enter both username and password.");
    return;
  }

  try {
    // 1) Ask ui-gateway to talk to real auth (/auth/login) and return JWT
    const res = await fetch("/ui-api/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: user, password: pass })
    });

    if (!res.ok) {
      alert("Login failed. Please check your credentials.");
      return;
    }

    const data = await res.json();
    const token = data.access_token;
    const tokenType = data.token_type || "bearer";

    if (!token) {
      alert("Login failed: no token returned from auth service.");
      return;
    }

    // 2) Store JWT locally for later use
    localStorage.setItem("lb_jwt", token);
    localStorage.setItem("lb_jwt_type", tokenType);

    // 3) Ask /ui-api/me (proxy to /auth/me) what this user's role is
    let role = "enduser";
    try {
      const meRes = await fetch("/ui-api/me", {
        headers: { "Authorization": `Bearer ${token}` }
      });

      if (meRes.ok) {
        const me = await meRes.json();
        // Heuristics depending on how your backend defines roles
        if (me.role) {
          role = me.role;
        } else if (Array.isArray(me.roles)) {
          if (me.roles.includes("hr")) role = "hr";
          else if (me.roles.includes("it")) role = "it";
          else if (me.roles.includes("admin")) role = "admin";
        }
      }
    } catch (e) {
      console.warn("Could not fetch /ui-api/me, defaulting to enduser.", e);
    }

    const profile = { user, role, ts: new Date().toISOString() };
    localStorage.setItem("lb_portal_profile", JSON.stringify(profile));

    // 4) Redirect based on discovered role
    if (role === "hr") {
      window.location.href = "hr-dashboard.html";
    } else if (role === "it" || role === "admin") {
      window.location.href = "it-dashboard.html";
    } else {
      window.location.href = "awareness.html";
    }
  } catch (e) {
    console.error(e);
    alert("Login error. Please try again later.");
  }
}
