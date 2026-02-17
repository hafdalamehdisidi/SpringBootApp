// ====== Estado ======
let JWT = null;
let lastJson = null;

let librosPage = 0;
let librosSize = 10;
let librosTotalPages = 0;

const $ = (id) => document.getElementById(id);

function apiBase() {
  return ($("api").value || "").replace(/\/+$/, "");
}
function v1(path) {
  return `${apiBase()}/api/v1${path}`;
}

function setAlert(type, msg) {
  const el = $("alert");
  el.className = `alert alert-${type}`;
  el.textContent = msg;
  el.classList.remove("d-none");
}
function clearAlert() {
  $("alert").classList.add("d-none");
  $("alert").textContent = "";
}

function setSubtitle(text) {
  $("subtitle").textContent = text;
}

function setSession(connected, info = "Desconectado") {
  const badge = $("sessionBadge");
  if (!connected) {
    badge.className = "badge badge-soft px-3 py-2";
    badge.textContent = "Desconectado";
    $("btnLogout").disabled = true;
    $("btnLibros").disabled = true;
    $("btnUsers").disabled = true;
    $("btnResources").disabled = true;
  } else {
    badge.className = "badge text-bg-success px-3 py-2";
    badge.textContent = info;
    $("btnLogout").disabled = false;
    $("btnLibros").disabled = false;
    $("btnResources").disabled = false;
    // btnUsers lo activamos si el token parece admin (heurística simple)
  }
}

function setJwtUI(jwt) {
  $("jwt").textContent = jwt || "";
  $("claims").textContent = jwt ? decodeJwtClaims(jwt) : "";
}

function decodeJwtClaims(token) {
  try {
    const payload = token.split(".")[1];
    const json = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.stringify(JSON.parse(json), null, 2);
  } catch {
    return "(No se pudo decodificar)";
  }
}

// ====== HTTP ======
async function requestJson(url, { method = "GET", body = null, auth = true } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (auth && JWT) headers["Authorization"] = `Bearer ${JWT}`;

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : null,
    mode: "cors",
    credentials: "omit",
  });

  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }

  if (!res.ok) {
    const msg = typeof data === "string" ? data : (data?.message || data?.error || JSON.stringify(data));
    throw new Error(`${res.status} ${res.statusText} — ${msg}`);
  }
  return data;
}

// ====== Render ======
function showRaw(json) {
  lastJson = json;
  $("out").textContent = json ? JSON.stringify(json, null, 2) : "";
}

function showSection(sectionId) {
  $("tables").classList.remove("d-none");
  $("librosSection").classList.add("d-none");
  $("usersSection").classList.add("d-none");
  $("resourceSection").classList.add("d-none");
  $(sectionId).classList.remove("d-none");
}

function clearTables() {
  $("tables").classList.add("d-none");
  $("librosTbody").innerHTML = "";
  $("usersTbody").innerHTML = "";
  $("resourceBox").textContent = "";
  $("librosMeta").textContent = "";
}

function renderLibros(pageObj) {
  // Spring Page<Libro> típico: { content:[], number, size, totalElements, totalPages, ... }
  const rows = pageObj?.content ?? [];
  librosPage = pageObj?.number ?? 0;
  librosTotalPages = pageObj?.totalPages ?? 0;

  $("librosTbody").innerHTML = rows.map(l => `
    <tr>
      <td class="mono">${l.id ?? ""}</td>
      <td>${escapeHtml(l.titulo ?? l.title ?? "")}</td>
      <td>${escapeHtml(l.autor ?? l.author ?? "")}</td>
      <td class="text-end mono">${l.anioPublicacion ?? l.anio ?? l.year ?? ""}</td>
    </tr>
  `).join("");

  $("librosMeta").textContent =
    `Página ${librosPage + 1} / ${librosTotalPages} · Total: ${pageObj?.totalElements ?? rows.length}`;

  $("btnPrev").disabled = librosPage <= 0;
  $("btnNext").disabled = librosPage >= librosTotalPages - 1 || librosTotalPages === 0;

  showSection("librosSection");
}

function renderUsers(users) {
  $("usersTbody").innerHTML = (users || []).map(u => `
    <tr>
      <td class="mono">${u.id ?? ""}</td>
      <td class="mono">${escapeHtml(u.email ?? "")}</td>
      <td>${escapeHtml(u.nombre ?? u.name ?? "")}</td>
      <td class="mono">${escapeHtml(formatRoles(u.roles ?? u.authorities ?? u.role ?? ""))}</td>
    </tr>
  `).join("");

  showSection("usersSection");
}

function renderResource(textOrObj) {
  $("resourceBox").textContent = typeof textOrObj === "string" ? textOrObj : JSON.stringify(textOrObj, null, 2);
  showSection("resourceSection");
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, s => ({
    "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"
  }[s]));
}

function formatRoles(r) {
  if (Array.isArray(r)) return r.join(", ");
  if (typeof r === "object" && r) return JSON.stringify(r);
  return String(r);
}

function setAdminButtonFromToken() {
  // Heurística simple: si el payload contiene ROLE_ADMIN, habilitamos /users
  const claims = decodeJwtClaims(JWT || "");
  const isAdmin = claims.includes("ROLE_ADMIN");
  $("btnUsers").disabled = !isAdmin;
  const info = isAdmin ? "Conectado (ADMIN)" : "Conectado";
  setSession(true, info);
}

// ====== Acciones ======
async function login() {
  clearAlert();
  clearTables();
  showRaw(null);
  setSubtitle("Conectando...");

  const email = $("email").value.trim();
  const password = $("password").value;

  const data = await requestJson(v1("/auth/signin"), {
    method: "POST",
    body: { email, password },
    auth: false
  });

  // Ajusta según tu DTO: JwtAuthenticationResponse
  JWT = data?.token || data?.jwt || data?.accessToken || data?.access_token || null;

  if (!JWT) {
    throw new Error("Respuesta sin token. Revisa el nombre del campo (token/jwt/accessToken).");
  }

  setJwtUI(JWT);
  setAdminButtonFromToken();

  setAlert("success", "Login correcto. Token guardado en memoria.");
  setSubtitle("Elige una acción: /libros, /users (admin) o /resources.");
  showRaw(data);
}

function logout() {
  JWT = null;
  lastJson = null;
  librosPage = 0;
  librosTotalPages = 0;
  setJwtUI("");
  setSession(false);
  clearTables();
  clearAlert();
  showRaw(null);
  setSubtitle("Sesión cerrada.");
}

async function loadLibros(page = 0) {
  clearAlert();
  clearTables();
  setSubtitle("Cargando libros...");

  const url = v1(`/libros?page=${page}&size=${librosSize}`);
  const data = await requestJson(url);

  showRaw(data);
  renderLibros(data);
  setSubtitle("Tabla de libros cargada correctamente.");
}

async function loadUsers() {
  clearAlert();
  clearTables();
  setSubtitle("Cargando usuarios (admin)...");

  const data = await requestJson(v1("/users"));
  showRaw(data);
  renderUsers(data);
  setSubtitle("Tabla de usuarios cargada.");
}

async function loadResources() {
  clearAlert();
  clearTables();
  setSubtitle("Cargando recurso protegido...");

  const data = await requestJson(v1("/resources"));
  showRaw(data);
  renderResource(data);
  setSubtitle("Recurso cargado.");
}

// ====== UI events ======
$("btnLogin").addEventListener("click", async () => {
  try { await login(); }
  catch (e) { setAlert("danger", e.message); setSubtitle("Error de login."); }
});

$("btnLogout").addEventListener("click", () => logout());

$("btnLibros").addEventListener("click", async () => {
  try { await loadLibros(0); }
  catch (e) { setAlert("danger", e.message); }
});

$("btnUsers").addEventListener("click", async () => {
  try { await loadUsers(); }
  catch (e) { setAlert("danger", e.message); }
});

$("btnResources").addEventListener("click", async () => {
  try { await loadResources(); }
  catch (e) { setAlert("danger", e.message); }
});

$("btnPrev").addEventListener("click", async () => {
  try { await loadLibros(librosPage - 1); }
  catch (e) { setAlert("danger", e.message); }
});

$("btnNext").addEventListener("click", async () => {
  try { await loadLibros(librosPage + 1); }
  catch (e) { setAlert("danger", e.message); }
});

$("btnClear").addEventListener("click", () => {
  clearAlert();
  clearTables();
  showRaw(null);
  setSubtitle("Salida limpiada.");
});

$("btnCopy").addEventListener("click", async () => {
  try {
    await navigator.clipboard.writeText($("out").textContent || "");
    setAlert("success", "JSON copiado al portapapeles.");
  } catch {
    setAlert("warning", "No se pudo copiar (permiso del navegador).");
  }
});

$("btnFill").addEventListener("click", () => {
  const v = $("preset").value;
  if (v === "user") {
    $("email").value = "alice.johnson@example.com";
    $("password").value = "password123";
  } else if (v === "admin") {
    $("email").value = "admin@example.com";
    $("password").value = "admin123";
  }
});

// Estado inicial
setSession(false);
setJwtUI("");
setSubtitle("Introduce la URL del backend, elige rol (opcional) y haz login.");
