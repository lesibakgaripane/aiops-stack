async function lbLogin() {
  const userEl = document.getElementById("lb-username");
  const passEl = document.getElementById("lb-password");

  if (!userEl || !passEl) {
    console.error("Login inputs not found in DOM");
    alert("Login form is not correctly loaded. Please refresh the page.");
    return;
  }

  const username = userEl.value.trim();
  const password = passEl.value;

  if (!username || !password) {
    alert("Please enter both username and password.");
    return;
  }

  try {
    const body = new URLSearchParams();
    body.append("username", username);
    body.append("password", password);

    const res = await fetch("/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString()
    });

    console.log("Login HTTP status", res.status);

    if (!res.ok) {
      alert("Login failed. Please check your credentials.");
      return;
    }

    const data = await res.json();
    console.log("Login payload", data);

    const token = data.access_token;
    const tokenType = data.token_type || "bearer";
    const effectiveUser = data.username || username;
    const role = data.role || "user";

    if (!token) {
      alert("Login failed: no token returned from auth service.");
      return;
    }

    // Store token + basic profile
    localStorage.setItem("lb_jwt", token);
    localStorage.setItem("lb_jwt_type", tokenType);
    localStorage.setItem("lb_username", effectiveUser);
    localStorage.setItem("lb_role", role);

    alert("Login successful for " + effectiveUser + " (" + role + ")");
    // For now, just send user to main portal landing
    window.location.href = "/";
  } catch (e) {
    console.error("Login exception", e);
    alert("Login error. Please try again later.");
  }
}
