function lbLogin(){
  const user = document.getElementById("lb-username").value.trim();
  const role = document.getElementById("lb-role").value;

  if (!user) {
    alert("Please enter your email / username.");
    return;
  }

  // Demo: store in localStorage (used later for metrics / profiling)
  const profile = { user, role, ts: new Date().toISOString() };
  localStorage.setItem("lb_portal_profile", JSON.stringify(profile));

  // Simple role routing (URLs kept as-is for now)
  if (role === "hr") {
    window.location.href = "hr-dashboard.html";
  } else if (role === "it" || role === "admin") {
    window.location.href = "it-dashboard.html";
  } else {
    window.location.href = "awareness.html";
  }
}
