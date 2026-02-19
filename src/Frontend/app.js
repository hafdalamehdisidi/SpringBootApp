(() => {
  // ----------------------------
  // State
  // ----------------------------
  let token = null;
  let lastText = "";
  let librosPage = 0;
  const librosSize = 10;

  let busyCount = 0;
  let selectedLibro = null;

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
    whoBadge: $("whoBadge"),
    roleBadge: $("roleBadge"),

    jwt: $("jwt"),
    claims: $("claims"),

    alert: $("alert"),
    alertUser: $("alertUser"),
    alertAdmin: $("alertAdmin"),

    viewLogin: $("viewLogin"),
    viewUser: $("viewUser"),
    viewAdmin: $("viewAdmin"),

    // USER
    btnUserRefresh: $("btnUserRefresh"),
    librosMeta: $("librosMeta"),
    librosTbody: $("librosTbody"),
    btnPrev: $("btnPrev"),
    btnNext: $("btnNext"),

    // ADMIN CRUD
    btnAdminRefresh: $("btnAdminRefresh"),
    editId: $("editId"),
    newTitulo: $("newTitulo"),
    newAutor: $("newAutor"),
    newIsbn: $("newIsbn"),
    btnCreateLibro: $("btnCreateLibro"),
    btnUpdateLibro: $("btnUpdateLibro"),
    btnDeleteLibro: $("btnDeleteLibro"),
    btnNewLibro: $("btnNewLibro"),

    librosTbodyAdmin: $("librosTbodyAdmin"),

    // ADMIN pruebas extra
    btnAdminUsers: $("btnAdminUsers"),
    btnAdminResource: $("btnAdminResource"),
    usersSection: $("usersSection"),
    usersTbody: $("usersTbody"),
    resourceSection: $("resourceSection"),
    resourceBox: $("resourceBox"),

    // OUT
    out: $("out"),
    btnCopy: $("btnCopy"),
    btnClear: $("btnClear"),
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
  function hideAlert(node) { node.classList.add("d-none"); }
  function hideAllAlerts() {
    hideAlert(el.alert); hideAlert(el.alertUser); hideAlert(el.alertAdmin);
  }

  function setBadge(text, connected) {
    el.sessionBadge.textContent = text;
    el.sessionBadge.classList.toggle("badge-soft", connected);
    el.sessionBadge.classList.toggle("bg-success-subtle", connected);
  }

  function setWho(email) { el.whoBadge.textContent = email || "—"; }
  function setRoles(roles) { el.roleBadge.textContent = (roles?.length ? roles.join(", ") : "—"); }

  function setOut(val) {
    lastText = typeof val === "string" ? val : JSON.stringify(val, null, 2);
    el.out.textContent = lastText;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (ch) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;",
    }[ch]));
  }

  function decodeJwtPayload(jwt) {
    try {
      const parts = jwt.split(".");
      if (parts.length !== 3) return null;

      const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
      const pad = b64.length % 4 ? "=".repeat(4 - (b64.length % 4)) : "";
      const bin = atob(b64 + pad);

      const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
      const json = new TextDecoder().decode(bytes);
      return JSON.parse(json);
    } catch {
      return null;
    }
  }

  function extractRolesFromClaims(claims) {
    if (!claims) return [];
    const roles = new Set();
    const pushMany = (arr) => Array.isArray(arr) && arr.forEach((x) => roles.add(String(x)));
    pushMany(claims.roles);
    pushMany(claims.authorities);
    if (typeof claims.scope === "string") claims.scope.split(" ").forEach((x) => roles.add(x));
    if (claims.role) roles.add(String(claims.role));
    return [...roles].filter(Boolean);
  }

  function isAdminByRoles(roleList) {
    return roleList.some((r) => r.includes("ROLE_ADMIN") || r === "ADMIN");
  }

  function claimsEmail(claims) {
    // ajusta si tu JWT usa otro claim: sub/email/username
    return claims?.email || claims?.sub || claims?.username || "";
  }

  function setViews(mode) {
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

  function setBusy(node, busy, labelBusy = "Procesando...") {
    if (!node) return;
    if (busy) {
      node.dataset._oldText = node.textContent;
      node.disabled = true;
      node.textContent = labelBusy;
    } else {
      node.disabled = false;
      if (node.dataset._oldText) node.textContent = node.dataset._oldText;
    }
  }

  function setGlobalBusy(busy) {
    busyCount += busy ? 1 : -1;
    if (busyCount < 0) busyCount = 0;
    const isBusy = busyCount > 0;

    // login
    el.btnLogin.disabled = isBusy;

    // user
    el.btnUserRefresh.disabled = isBusy;

    // admin
    el.btnAdminRefresh.disabled = isBusy;
    el.btnCreateLibro.disabled = isBusy;
    el.btnNewLibro.disabled = isBusy;
    el.btnAdminUsers.disabled = isBusy;
    el.btnAdminResource.disabled = isBusy;
    // update/delete dependen también de si hay selección
    if (isBusy) {
      el.btnUpdateLibro.disabled = true;
      el.btnDeleteLibro.disabled = true;
    } else {
      el.btnUpdateLibro.disabled = !(selectedLibro?.id);
      el.btnDeleteLibro.disabled = !(selectedLibro?.id);
    }
  }

  function clearUserTable() {
    el.librosTbody.innerHTML = "";
    el.librosMeta.textContent = "";
    el.btnPrev.disabled = true;
    el.btnNext.disabled = true;
  }

  function clearAdminPanels() {
    el.usersSection.classList.add("d-none");
    el.usersTbody.innerHTML = "";
    el.resourceSection.classList.add("d-none");
    el.resourceBox.textContent = "";
  }

  function clearLibroForm() {
    selectedLibro = null;
    el.editId.value = "";
    el.newTitulo.value = "";
    el.newAutor.value = "";
    el.newIsbn.value = "";
    el.btnUpdateLibro.disabled = true;
    el.btnDeleteLibro.disabled = true;
  }

  function fillLibroForm(libro) {
    selectedLibro = libro;
    el.editId.value = String(libro?.id ?? "");
    el.newTitulo.value = libro?.titulo ?? "";
    el.newAutor.value = libro?.autor ?? "";
    el.newIsbn.value = libro?.isbn ?? "";
    el.btnUpdateLibro.disabled = !(libro?.id);
    el.btnDeleteLibro.disabled = !(libro?.id);
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

    // 401 => sesión caducada => logout
    if (res.status === 401 && auth) {
      logout("Sesión caducada. Vuelve a iniciar sesión.");
      throw new Error("401 Unauthorized");
    }

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
  // Routing: vista según JWT
  // ----------------------------
  async function routeAfterLogin() {
    updateTokenUI();
    setBadge("Conectado", true);

    const claims = decodeJwtPayload(token);
    const roles = extractRolesFromClaims(claims);
    const email = claimsEmail(claims);

    setWho(email);
    setRoles(roles);

    hideAllAlerts();
    clearAdminPanels();
    clearLibroForm();

    if (isAdminByRoles(roles)) {
      setViews("admin");
      setOut({ mode: "ADMIN", email, roles });
      await adminRefresh();
    } else {
      setViews("user");
      setOut({ mode: "USER", email, roles });
      await loadLibros(0);
    }
  }

  // ----------------------------
  // Login / logout
  // ----------------------------
  async function login() {
    hideAllAlerts();

    const email = el.email.value.trim();
    const password = el.password.value;

    if (!email || !password) {
      showAlert(el.alert, "warning", "Rellena email y password.");
      return;
    }

    if (el.btnLogin.disabled) return;

    setBusy(el.btnLogin, true, "Entrando...");
    setGlobalBusy(true);

    try {
      const data = await request("/api/v1/auth/signin", {
        method: "POST",
        auth: false,
        body: { email, password },
      });

      const t = data?.token || data?.jwt || data?.accessToken || data?.access_token;
      if (!t) throw new Error("Respuesta sin token (token/jwt/accessToken).");

      token = t;
      await routeAfterLogin();
    } catch (e) {
      token = null;
      updateTokenUI();
      setViews("login");
      setBadge("Desconectado", false);
      setWho("");
      setRoles([]);
      showAlert(el.alert, "danger", `Login fallido: ${e.message}`);
    } finally {
      setBusy(el.btnLogin, false);
      setGlobalBusy(false);
    }
  }

  function logout(msg = null) {
    token = null;
    updateTokenUI();

    setViews("login");
    setBadge("Desconectado", false);
    setWho("");
    setRoles([]);

    clearUserTable();
    clearAdminPanels();
    clearLibroForm();

    setOut("");
    if (msg) showAlert(el.alert, "warning", msg);
  }

  // ----------------------------
  // USER: ver libros
  // ----------------------------
  async function loadLibros(page = 0) {
    if (!token) return;
    hideAllAlerts();
    setGlobalBusy(true);

    try {
      const data = await request(`/api/v1/libros?page=${page}&size=${librosSize}`, { method: "GET" });
      const content = Array.isArray(data?.content) ? data.content : [];

      librosPage = Number.isFinite(data?.number) ? data.number : page;
      const totalPages = Number.isFinite(data?.totalPages) ? data.totalPages : 0;

      const isLastByContent = content.length < librosSize;

      el.librosTbody.innerHTML = content.map((l) => `
        <tr>
          <td>${l?.id ?? ""}</td>
          <td>${escapeHtml(l?.titulo ?? "")}</td>
          <td>${escapeHtml(l?.autor ?? "")}</td>
          <td class="mono">${escapeHtml(l?.isbn ?? "")}</td>
        </tr>
      `).join("");

      const totalLabel = totalPages > 0 ? totalPages : "?";
      el.librosMeta.textContent = `Página ${librosPage + 1}/${totalLabel} · ${data?.totalElements ?? "?"} elementos`;

      el.btnPrev.disabled = librosPage <= 0;
      if (totalPages > 0) el.btnNext.disabled = librosPage >= totalPages - 1;
      else el.btnNext.disabled = isLastByContent;

      setOut(data);
    } catch (e) {
      showAlert(el.alertUser, "danger", `Error cargando libros: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setGlobalBusy(false);
    }
  }

  // ----------------------------
  // ADMIN: CRUD libros
  // ----------------------------
  async function adminRefresh() {
    hideAllAlerts();
    clearAdminPanels();
    clearLibroForm();
    setGlobalBusy(true);

    try {
      const data = await request(`/api/v1/libros?page=0&size=${librosSize}`, { method: "GET" });
      const content = Array.isArray(data?.content) ? data.content : [];

      el.librosTbodyAdmin.innerHTML = content.map((l) => `
        <tr>
          <td>${l?.id ?? ""}</td>
          <td>${escapeHtml(l?.titulo ?? "")}</td>
          <td>${escapeHtml(l?.autor ?? "")}</td>
          <td class="mono">${escapeHtml(l?.isbn ?? "")}</td>
          <td class="text-nowrap">
            <button class="btn btn-sm btn-outline-warning me-1" data-action="edit" data-id="${l?.id ?? ""}">Editar</button>
            <button class="btn btn-sm btn-outline-danger" data-action="delete" data-id="${l?.id ?? ""}">Borrar</button>
          </td>
        </tr>
      `).join("");

      setOut(data);
    } catch (e) {
      showAlert(el.alertAdmin, "danger", `Error adminRefresh: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setGlobalBusy(false);
    }
  }

  async function adminCreateLibro() {
    hideAllAlerts();

    const titulo = (el.newTitulo.value || "").trim();
    const autor = (el.newAutor.value || "").trim();
    const isbn = (el.newIsbn.value || "").trim();

    if (!titulo || !autor || !isbn) {
      showAlert(el.alertAdmin, "warning", "Rellena título, autor e ISBN.");
      return;
    }

    setBusy(el.btnCreateLibro, true, "Creando...");
    setGlobalBusy(true);

    try {
      const created = await request("/api/v1/libros", {
        method: "POST",
        body: { titulo, autor, isbn },
      });
      showAlert(el.alertAdmin, "success", "Libro creado.");
      setOut(created);
      clearLibroForm();
      await adminRefresh();
    } catch (e) {
      showAlert(el.alertAdmin, "danger", `Error creando libro: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setBusy(el.btnCreateLibro, false);
      setGlobalBusy(false);
    }
  }

  async function adminGetLibroAndFill(id) {
    hideAllAlerts();
    setGlobalBusy(true);

    try {
      const libro = await request(`/api/v1/libros/${id}`, { method: "GET" });
      fillLibroForm(libro);
      showAlert(el.alertAdmin, "info", `Editando libro ID=${id}`);
      setOut(libro);
    } catch (e) {
      showAlert(el.alertAdmin, "danger", `Error cargando libro ${id}: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setGlobalBusy(false);
    }
  }

  async function adminUpdateLibro() {
    hideAllAlerts();

    const id = Number(el.editId.value);
    const titulo = (el.newTitulo.value || "").trim();
    const autor = (el.newAutor.value || "").trim();
    const isbn = (el.newIsbn.value || "").trim();

    if (!Number.isFinite(id) || id <= 0) {
      showAlert(el.alertAdmin, "warning", "Selecciona un libro (Editar) antes de actualizar.");
      return;
    }
    if (!titulo || !autor || !isbn) {
      showAlert(el.alertAdmin, "warning", "Rellena título, autor e ISBN.");
      return;
    }

    setBusy(el.btnUpdateLibro, true, "Actualizando...");
    setGlobalBusy(true);

    try {
      const updated = await request(`/api/v1/libros/${id}`, {
        method: "PUT",
        body: { titulo, autor, isbn },
      });
      showAlert(el.alertAdmin, "success", "Libro actualizado.");
      setOut(updated);
      await adminRefresh();
      fillLibroForm(updated);
    } catch (e) {
      showAlert(el.alertAdmin, "danger", `Error actualizando: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setBusy(el.btnUpdateLibro, false);
      setGlobalBusy(false);
    }
  }

  async function adminDeleteLibro(idFromBtn = null) {
    hideAllAlerts();
    const id = idFromBtn ?? Number(el.editId.value);

    if (!Number.isFinite(id) || id <= 0) {
      showAlert(el.alertAdmin, "warning", "Selecciona un libro (Editar) antes de eliminar.");
      return;
    }

    // eslint-disable-next-line no-restricted-globals
    if (!confirm(`¿Eliminar libro ID=${id}?`)) return;

    setBusy(el.btnDeleteLibro, true, "Eliminando...");
    setGlobalBusy(true);

    try {
      await request(`/api/v1/libros/${id}`, { method: "DELETE" });
      showAlert(el.alertAdmin, "success", "Libro eliminado.");
      setOut({ deletedId: id });
      clearLibroForm();
      await adminRefresh();
    } catch (e) {
      showAlert(el.alertAdmin, "danger", `Error eliminando: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setBusy(el.btnDeleteLibro, false);
      setGlobalBusy(false);
    }
  }

  // ----------------------------
  // ADMIN: pruebas extra
  // ----------------------------
  async function adminUsers() {
    hideAllAlerts();
    el.resourceSection.classList.add("d-none");
    el.resourceBox.textContent = "";
    setGlobalBusy(true);

    try {
      const data = await request("/api/v1/users", { method: "GET" });
      const list = Array.isArray(data) ? data : [];
      el.usersSection.classList.remove("d-none");
      el.usersTbody.innerHTML = list.map((u) => `
        <tr>
          <td>${u?.id ?? ""}</td>
          <td>${escapeHtml(u?.email ?? "")}</td>
          <td>${escapeHtml(u?.nombre ?? "")}</td>
          <td class="mono">${escapeHtml(Array.isArray(u?.roles) ? u.roles.join(", ") : "")}</td>
        </tr>
      `).join("");
      setOut(data);
    } catch (e) {
      showAlert(el.alertAdmin, "danger", `Error /users: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setGlobalBusy(false);
    }
  }

  async function adminResource() {
    hideAllAlerts();
    el.usersSection.classList.add("d-none");
    el.usersTbody.innerHTML = "";
    setGlobalBusy(true);

    try {
      const data = await request("/api/v1/resources", { method: "GET" });
      el.resourceSection.classList.remove("d-none");
      el.resourceBox.textContent = typeof data === "string" ? data : JSON.stringify(data, null, 2);
      setOut(data);
    } catch (e) {
      showAlert(el.alertAdmin, "danger", `Error /resources: ${e.message}`);
      setOut({ error: e.message });
    } finally {
      setGlobalBusy(false);
    }
  }

  // ----------------------------
  // Presets demo (banco de pruebas)
  // ----------------------------
  el.btnFill.addEventListener("click", () => {
    hideAllAlerts();
    const p = el.preset.value;

    if (p === "user") {
      el.email.value = "alice.johnson@example.com";
      el.password.value = "password123";
    } else if (p === "admin") {
      el.email.value = "bob.smith@example.com";
      el.password.value = "password456"; // SOLO DEMO
      showAlert(el.alert, "warning", "ADMIN: credenciales autocompletadas SOLO DEMO. No usar en producción.");
    }
  });

  // ----------------------------
  // Events
  // ----------------------------
  el.btnLogin.addEventListener("click", login);
  el.btnLogout.addEventListener("click", () => logout());

  el.btnUserRefresh.addEventListener("click", () => loadLibros(librosPage));
  el.btnPrev.addEventListener("click", () => loadLibros(Math.max(0, librosPage - 1)));
  el.btnNext.addEventListener("click", () => loadLibros(librosPage + 1));

  el.btnAdminRefresh.addEventListener("click", adminRefresh);
  el.btnCreateLibro.addEventListener("click", adminCreateLibro);
  el.btnUpdateLibro.addEventListener("click", adminUpdateLibro);
  el.btnDeleteLibro.addEventListener("click", () => adminDeleteLibro(null));
  el.btnNewLibro.addEventListener("click", () => { hideAllAlerts(); clearLibroForm(); });

  el.btnAdminUsers.addEventListener("click", adminUsers);
  el.btnAdminResource.addEventListener("click", adminResource);

  // Delegación: Edit/Delete en tabla admin
  el.librosTbodyAdmin.addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-action]");
    if (!btn) return;
    const id = Number(btn.dataset.id);
    if (!Number.isFinite(id) || id <= 0) return;

    if (btn.dataset.action === "edit") adminGetLibroAndFill(id);
    if (btn.dataset.action === "delete") adminDeleteLibro(id);
  });

  // Copy / clear OUT
  el.btnCopy.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(lastText || "");
      showAlert(el.alertAdmin, "success", "Copiado al portapapeles.");
      setTimeout(() => hideAlert(el.alertAdmin), 1200);
    } catch {
      showAlert(el.alertAdmin, "warning", "No se pudo copiar (permiso del navegador).");
    }
  });

  el.btnClear.addEventListener("click", () => {
    hideAllAlerts();
    setOut("");
    clearAdminPanels();
  });

  // Enter = login (email y password)
  const onEnterLogin = (e) => { if (e.key === "Enter") login(); };
  el.email.addEventListener("keydown", onEnterLogin);
  el.password.addEventListener("keydown", onEnterLogin);

  // Init
  setViews("login");
  setBadge("Desconectado", false);
  setWho("");
  setRoles([]);
  clearLibroForm();

  el.preset.value = "user";
  el.btnFill.click();
})();

