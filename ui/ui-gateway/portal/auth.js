async function lbLogin(event) {
  if (event) event.preventDefault();

  const userEl = document.getElementById("lb-username");
  const passEl = document.getElementById("lb-password");
  const errorEl = document.getElementById("lb-error");

  if (!userEl || !passEl || !errorEl) {
    alert("Login form not loaded correctly.");
    return;
  }

  const username = userEl.value.trim();
  const password = passEl.value;

  // Clear previous error
  errorEl.textContent = "";
  errorEl.classList.remove("visible");

  if (!username || !password) {
    errorEl.textContent = "Please enter both username and password.";
    errorEl.classList.add("visible");
    return;
  }

  try {
    const params = new URLSearchParams();
    params.append("username", username);
    params.append("password", password);

    // EXACTLY like your working curl:
    // curl -X POST http://127.0.0.1:8089/auth/login \
    //   -H "Content-Type: application/x-www-form-urlencoded" \
    //   -d "username=admin&password=password"
    const res = await fetch("/auth/login", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    console.log("Login response status:", res.status);

    if (!res.ok) {
      const txt = await res.text();
      console.log("Login response body:", txt);
      errorEl.textContent = "Invalid credentials or account not provisioned.";
      errorEl.classList.add("visible");
      return;
    }

    const data = await res.json();
    console.log("Login response JSON:", data);

    const token = data.access_token;
    const tokenType = data.token_type || "bearer";
    const role = data.role || "user";

    if (!token) {
      errorEl.textContent = "Login failed: token not returned by server.";
      errorEl.classList.add("visible");
      return;
    }

    // Store token + basic profile
    localStorage.setItem("lb_jwt", token);
    localStorage.setItem("lb_jwt_type", tokenType);
    localStorage.setItem("lb_username", username);
    localStorage.setItem("lb_role", role);

    // Optional: verify /api/auth/me
    try {
      const meRes = await fetch("/api/auth/me", {
        headers: { Authorization: `Bearer ${token}` },
      });
      console.log("Auth /api/auth/me status:", meRes.status);
      if (meRes.ok) {
        const me = await meRes.json();
        console.log("Auth /api/auth/me JSON:", me);
      }
    } catch (e) {
      console.warn("Auth /api/auth/me check failed", e);
    }

    // Redirect into main React portal
    window.location.href = "/";
  } catch (err) {
    console.error("Login error", err);
    errorEl.textContent = "Unexpected error during login.";
    errorEl.classList.add("visible");
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("lb-login-form");
  if (form) {
    form.addEventListener("submit", lbLogin);
  }
});
