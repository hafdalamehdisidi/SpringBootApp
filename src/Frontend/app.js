(() => {
  // ----------------------------
  // State
  // ----------------------------
  let token = null;
  let lastText = "";
  let librosPage = 0;
  const librosSize = 10;
  let librosTotalPages = 0;

  // ----------------------------
  // DOM
  // ----------------------------
  const $ = (id) => document.getElementById(id);

  const el = {
    api: $("api"),
    preset: $("preset"),
    btnFill: $("btnFill"),
    email: $("email"),
    password: $("password"),
    btnLogin: $("btnLogin"),
    btnLogout: $("btnLogout"),
    sessionBadge: $("sessionBadge"),

    jwt: $("jwt"),
    claims: $("claims"),

    alert: $("alert"),
    alert2: $("alert2"),

    viewLogin: $("viewLogin"),
    viewUser: $("viewUser"),
    viewAdmin: $("viewAdmin"),

    // USER view
    btnUserRefresh: $("btnUserRefresh"),
    librosMeta: $("librosMeta"),
    librosTbody: $("librosTbody"),
    btnPrev: $("btnPrev"),
    btnNext: $("btnNext"),

    // ADMIN view
    btnAdminRefresh: $("btnAdminRefresh"),
    btnAdminUsers: $("btnAdminUsers"),
    btnAdminLibros: $("btnAdminLibros"),
    btnAdminResource: $("btnAdminResource"),

    newTitulo: $("newTitulo"),
    newAutor: $("newAutor"),
    newIsbn: $("newIsbn"),
    btnCreateLibro: $("btnCreateLibro"),

    out: $("out"),
    btnCopy: $("btnCopy"),
    btnClear: $("btnClear"),

    adminTables: $("adminTables"),
    usersSection: $("usersSection"),
    usersTbody: $("usersTbody"),

    resourceSection: $("resourceSection"),
    resourceBox: $("resourceBox"),

    librosSectionAdmin: $("librosSectionAdmin"),
    librosTbodyAdmin: $("librosTbodyAdmin"),
  };

  // ----------------------------
  // Helpers
  // ----------------------------
  const apiBase = () => (el.api.value || "").replace(/\/+$/, "");

  function showAlert(node, kind, msg) {
    node.className = `alert alert-${kind}`;
    node.textContent = msg;
    node.classList.remove("d-none");
  }
  function hideAlert(node) {
    node.classList.add("d-none");
  }

  function setBadge(text, connected) {
    el.sessionBadge.textContent = text;
    el.sessionBadge.classList.toggle("badge-soft", true);
    if (connected) el.sessionBadge.classList.add("bg-success-subtle");
    else el.sessionBadge.classList.remove("bg-success-subtle");
  }

  function setOut(val) {
    lastText = typeof val === "string" ? val : JSON.stringify(val, null, 2);
    el.out.textContent = lastText;
  }

  function escapeHtml(s) {
    return String(s)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function decodeJwtPayload(jwt) {
    try {
      const parts = jwt.split(".");
      if (parts.length !== 3) return null;
      const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
      const json = decodeURIComponent(
        atob(b64)
          .split("")
          .map((c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2))
          .join("")
      );
      return JSON.parse(json);
    } catch {
      return null;
    }
  }

  function extractRolesFromClaims(claims) {
    if (!claims) return [];

    // casos típicos: roles, authorities, scope, realm_access.roles, etc.
    const roles = new Set();

    const pushMany = (arr) => {
      if (Array.isArray(arr)) arr.forEach((x) => roles.add(String(x)));
    };

    pushMany(claims.roles);
    pushMany(claims.authorities);

    // scope suele venir como string
    if (typeof claims.scope === "string") {
      claims.scope.split(" ").forEach((x) => roles.add(x));
    }

    // a veces viene en "role"
    if (claims.role) roles.add(String(claims.role));

    // filtra vacíos
    return [...roles].filter(Boolean);
  }

  function isAdminByRoles(roleList) {
    return roleList.some((r) => r.includes("ROLE_ADMIN") || r === "ADMIN");
  }

  function setViews(mode) {
    // mode: "login" | "user" | "admin"
    el.viewLogin.classList.toggle("d-none", mode !== "login");
    el.viewUser.classList.toggle("d-none", mode !== "user");
    el.viewAdmin.classList.toggle("d-none", mode !== "admin");

    el.btnLogout.disabled = mode === "login";
  }

  function updateTokenUI() {
    el.jwt.textContent = token || "";
    const claims = token ? decodeJwtPayload(token) : null;
    el.claims.textContent = claims ? JSON.stringify(claims, null, 2) : "";
  }

  function clearAdminPanels() {
    el.adminTables.classList.add("d-none");
    el.usersSection.classList.add("d-none");
    el.resourceSection.classList.add("d-none");
    el.librosSectionAdmin.classList.add("d-none");
    el.usersTbody.innerHTML = "";
    el.resourceBox.textContent = "";
    el.librosTbodyAdmin.innerHTML = "";
  }

  function clearUserTable() {
    el.librosTbody.innerHTML = "";
    el.librosMeta.textContent = "";
    el.btnPrev.disabled = true;
    el.btnNext.disabled = true;
  }

  // ----------------------------
  // HTTP
  // ----------------------------
  async function request(path, { method = "GET", body = null, auth = true } = {}) {
    const url = apiBase() + path;
    const headers = {};
    if (body != null) headers["Content-Type"] = "application/json";
    if (auth && token) headers["Authorization"] = `Bearer ${token}`;

    const res = await fetch(url, {
      method,
      headers,
      body: body != null ? JSON.stringify(body) : null,
    });

    const ct = res.headers.get("content-type") || "";
    let data;
    if (ct.includes("application/json")) data = await res.json().catch(() => null);
    else data = await res.text().catch(() => "");

    if (!res.ok) {
      const details = typeof data === "string" ? data : JSON.stringify(data);
      throw new Error(`${res.status} ${res.statusText}${details ? " — " + details : ""}`);
    }
    return data;
  }

  // ----------------------------
  // Core: decide vista según rol
  // ----------------------------
  async function routeAfterLogin() {
    updateTokenUI();
    setBadge("Conectado", true);

    const claims = decodeJwtPayload(token);
    const roles = extractRolesFromClaims(claims);
    const adminFromJwt = isAdminByRoles(roles);

    // Si ya lo sabemos por JWT
    if (adminFromJwt) {
      setViews("admin");
      setOut({ info: "Modo ADMIN (por JWT)", roles });
      hideAlert(el.alert);
      hideAlert(el.alert2);
      await adminRefresh();
      return;
    }

    // Fallback: probar endpoint admin
    try {
      await request("/api/v1/users", { method: "GET" }); // si entra, es admin
      setViews("admin");
      setOut({ info: "Modo ADMIN (por prueba /users)", roles });
      await adminRefresh();
    } catch (e) {
      // 403 => no admin => user
      setViews("user");
      setOut({ info: "Modo USER", roles, note: "Si /users da 403 es normal en USER." });
      await loadLibros(0, "user");
    }
  }

  // ----------------------------
  // Login
  // ----------------------------
  async function login() {
    hideAlert(el.alert);
    hideAlert(el.alert2);

    const email = el.email.value.trim();
    const password = el.password.value;

    if (!email || !password) {
      showAlert(el.alert, "warning", "Rellena email y password.");
      return;
    }

    try {
      const data = await request("/api/v1/auth/signin", {
        method: "POST",
        auth: false,
        body: { email, password },
      });

      const t = data?.token || data?.jwt || data?.accessToken || data?.access_token;
      if (!t) throw new Error("Respuesta sin token (token/jwt/accessToken).");

      token = t;
      updateTokenUI();
      await routeAfterLogin();
    } catch (e) {
      token = null;
      updateTokenUI();
      setViews("login");
      setBadge("Desconectado", false);
      showAlert(el.alert, "danger", `Login fallido: ${e.message}`);
    }
  }

  function logout() {
    token = null;
    updateTokenUI();
    setViews("login");
    setBadge("Desconectado", false);
    clearUserTable();
    clearAdminPanels();
    setOut("");
  }

  // ----------------------------
  // USER: libros
  // ----------------------------
  async function loadLibros(page = 0, target = "user") {
    if (!token) return;
    hideAlert(el.alert);
    hideAlert(el.alert2);

    try {
      const data = await request(`/api/v1/libros?page=${page}&size=${librosSize}`, { method: "GET" });
      const content = Array.isArray(data?.content) ? data.content : [];
      librosPage = Number.isFinite(data?.number) ? data.number : page;
      librosTotalPages = Number.isFinite(data?.totalPages) ? data.totalPages : 0;

      if (target === "user") {
        el.librosTbody.innerHTML = content.map((l) => `
          <tr>
            <td>${l?.id ?? ""}</td>
            <td>${escapeHtml(l?.titulo ?? "")}</td>
            <td>${escapeHtml(l?.autor ?? "")}</td>
            <td class="mono">${escapeHtml(l?.isbn ?? "")}</td>
          </tr>
        `).join("");

        el.librosMeta.textContent = `Página ${librosPage + 1}/${Math.max(librosTotalPages, 1)} · ${data?.totalElements ?? "?"} elementos`;
        el.btnPrev.disabled = librosPage <= 0;
        el.btnNext.disabled = librosTotalPages ? (librosPage >= librosTotalPages - 1) : true;
      } else {
        // admin table
        el.adminTables.classList.remove("d-none");
        el.librosSectionAdmin.classList.remove("d-none");
        el.librosTbodyAdmin.innerHTML = content.map((l) => `
          <tr>
            <td>${l?.id ?? ""}</td>
            <td>${escapeHtml(l?.titulo ?? "")}</td>
            <td>${escapeHtml(l?.autor ?? "")}</td>
            <td class="mono">${escapeHtml(l?.isbn ?? "")}</td>
          </tr>
        `).join("");
      }

      setOut(data);
    } catch (e) {
      const node = (target === "user") ? el.alert : el.alert2;
      showAlert(node, "danger", `Error /libros: ${e.message}`);
      setOut({ error: e.message });
    }
  }

  // ----------------------------
  // ADMIN: dashboard
  // ----------------------------
  async function adminRefresh() {
    // por defecto: enseñar libros
    clearAdminPanels();
    await loadLibros(0, "admin");
  }

  async function adminUsers() {
    clearAdminPanels();
    hideAlert(el.alert2);

    try {
      const data = await request("/api/v1/users", { method: "GET" });
      const list = Array.isArray(data) ? data : [];

      el.adminTables.classList.remove("d-none");
      el.usersSection.classList.remove("d-none");
      el.usersTbody.innerHTML = list.map((u) => {
        const roles = Array.isArray(u?.roles) ? u.roles.join(", ") : "";
        return `
          <tr>
            <td>${u?.id ?? ""}</td>
            <td>${escapeHtml(u?.email ?? "")}</td>
            <td>${escapeHtml(u?.nombre ?? "")}</td>
            <td class="mono">${escapeHtml(roles)}</td>
          </tr>
        `;
      }).join("");

      setOut(data);
    } catch (e) {
      showAlert(el.alert2, "danger", `Error /users: ${e.message}`);
      setOut({ error: e.message });
    }
  }

  async function adminResource() {
    clearAdminPanels();
    hideAlert(el.alert2);

    try {
      const data = await request("/api/v1/resources", { method: "GET" });

      el.adminTables.classList.remove("d-none");
      el.resourceSection.classList.remove("d-none");
      el.resourceBox.textContent = (typeof data === "string") ? data : JSON.stringify(data, null, 2);

      setOut(data);
    } catch (e) {
      showAlert(el.alert2, "danger", `Error /resources: ${e.message}`);
      setOut({ error: e.message });
    }
  }

  async function adminCreateLibro() {
    hideAlert(el.alert2);

    const titulo = (el.newTitulo.value || "").trim();
    const autor = (el.newAutor.value || "").trim();
    const isbn = (el.newIsbn.value || "").trim();

    if (!titulo || !autor || !isbn) {
      showAlert(el.alert2, "warning", "Rellena título, autor e ISBN.");
      return;
    }

    try {
      const created = await request("/api/v1/libros", {
        method: "POST",
        body: { titulo, autor, isbn },
      });
      setOut(created);
      showAlert(el.alert2, "success", "Libro creado. Recargando lista...");
      await loadLibros(0, "admin");
    } catch (e) {
      showAlert(el.alert2, "danger", `Error creando libro: ${e.message}`);
      setOut({ error: e.message });
    }
  }

  // ----------------------------
  // UI preset: Alice / Bob
  // ----------------------------
  el.btnFill.addEventListener("click", () => {
    const p = el.preset.value;
    if (p === "user") {
      el.email.value = "alice.johnson@example.com";
      el.password.value = "password123";
    } else if (p === "admin") {
      el.email.value = "bob.smith@example.com";
      el.password.value = "password456";
    }
  });

  el.btnLogin.addEventListener("click", login);
  el.btnLogout.addEventListener("click", logout);

  // USER paging
  el.btnPrev.addEventListener("click", () => loadLibros(Math.max(0, librosPage - 1), "user"));
  el.btnNext.addEventListener("click", () => loadLibros(librosPage + 1, "user"));
  el.btnUserRefresh.addEventListener("click", () => loadLibros(librosPage, "user"));

  // ADMIN actions
  el.btnAdminRefresh.addEventListener("click", adminRefresh);
  el.btnAdminUsers.addEventListener("click", adminUsers);
  el.btnAdminLibros.addEventListener("click", () => loadLibros(0, "admin"));
  el.btnAdminResource.addEventListener("click", adminResource);
  el.btnCreateLibro.addEventListener("click", adminCreateLibro);

  // Copy / clear
  el.btnCopy.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(lastText || "");
      showAlert(el.alert2, "success", "Copiado al portapapeles.");
      setTimeout(() => hideAlert(el.alert2), 1200);
    } catch {
      showAlert(el.alert2, "warning", "No se pudo copiar (permiso del navegador).");
    }
  });

  el.btnClear.addEventListener("click", () => {
    hideAlert(el.alert2);
    setOut("");
    clearAdminPanels();
  });

  // Enter = login
  el.password.addEventListener("keydown", (e) => {
    if (e.key === "Enter") login();
  });

  // Init
  setViews("login");
  setBadge("Desconectado", false);
  el.preset.value = "user";
  el.btnFill.click();
})();

