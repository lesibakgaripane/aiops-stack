document.addEventListener("DOMContentLoaded", () => {
  // Smooth load styling
  document.body.classList.add("portal-loaded");

  const auth = window.aiopsAuth ? window.aiopsAuth.getAuth() : null;
  const role = auth && auth.role ? auth.role : null;

  // ----------------------------
  // Role badge text
  // ----------------------------
  let label = "End-user mode";
  if (role === "admin") {
    label = "Administrator mode";
  } else if (role === "superuser") {
    label = "Operator mode";
  }

  const banner = document.querySelector("[data-role-banner]");
  if (banner) {
    banner.textContent = label;
  }

  if (!role) {
    return; // no RBAC changes if we don't know the role yet
  }

  // ----------------------------
  // RBAC: hide/show nav items
  // ----------------------------
  const linkAIOps = document.querySelector("a[href='aiops.html']");
  const linkAwareness = document.querySelector("a[href='awareness.html']");
  const linkEcosystem = document.querySelector("a[href='ecosystem.html']");

  // admin: full access (no changes)
  if (role === "admin") {
    return;
  }

  // operator / superuser: AIOps + Ecosystem only
  if (role === "superuser") {
    if (linkAwareness) linkAwareness.style.display = "none";
    return;
  }

  // end-user: Awareness only
  if (role === "user") {
    if (linkAIOps) linkAIOps.style.display = "none";
    if (linkEcosystem) linkEcosystem.style.display = "none";
  }
});
