#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Colores / mensajes (UTF-8 limpio)
# -----------------------------
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; BLUE="\033[0;34m"; RESET="\033[0m"
say() { echo -e "${BLUE}==>${RESET} $*"; }
ok()  { echo -e "${GREEN}[OK]${RESET} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET} $*"; }
err() { echo -e "${RED}[ERR]${RESET} $*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "No existe el comando: $1"; exit 1; }
}

# -----------------------------
# Root del proyecto (subiendo directorios hasta /)
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_up() {
  local dir="$1"
  while :; do
    if [[ -f "$dir/docker-compose.yml" ]]; then
      echo "$dir"
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="$(cd "$dir/.." && pwd)"
  done
  return 1
}

ROOT_DIR="$(find_up "$SCRIPT_DIR" || true)"
if [[ -z "${ROOT_DIR:-}" ]]; then
  err "No encuentro docker-compose.yml subiendo desde: $SCRIPT_DIR"
  exit 1
fi

COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
cd_root() { cd "$ROOT_DIR"; }

# -----------------------------
# Utilidades de red: IP privada y URLs para acceso desde otras máquinas
# -----------------------------
get_private_ip() {
  # Preferimos la ruta por defecto (lo normal en una RPi)
  local ip=""
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
  fi

  # Fallback: hostname -I
  if [[ -z "${ip:-}" ]] && command -v hostname >/dev/null 2>&1; then
    # Cogemos la primera IPv4 que parezca privada
    ip="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' | head -n1 || true)"
  fi

  # Último recurso: cualquier IPv4 no-loopback
  if [[ -z "${ip:-}" ]] && command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | head -n1 || true)"
  fi

  echo "${ip:-}"
}

print_access_urls() {
  local ip
  ip="$(get_private_ip || true)"

  echo
  say "Accesos locales:"
  ok "  Frontend  : http://localhost:8081"
  ok "  Backend   : http://localhost:9091"
  ok "  Swagger UI: http://localhost:8083"
  ok "  MySQL     : localhost:3306"
  echo

  if [[ -n "${ip:-}" ]]; then
    say "Accesos desde OTRA máquina en tu red (LAN):"
    ok "  Frontend  : http://${ip}:8081"
    ok "  Backend   : http://${ip}:9091"
    ok "  Swagger UI: http://${ip}:8083"
    ok "  MySQL     : ${ip}:3306"
    echo
    warn "Nota: si usas Swagger UI desde otra máquina, y tu openapi.yaml tiene servers: http://localhost:9091,"
    warn "      en el navegador 'localhost' será TU PC, no la Raspberry. Añade también http://${ip}:9091 como server."
  else
    warn "No pude detectar una IP privada automáticamente (¿sin red?)."
    warn "Prueba: hostname -I  o  ip a"
  fi
}

# -----------------------------
# Auto-fetch del backend (GitHub)
# -----------------------------
BACKEND_REPO_URL="https://github.com/profeInformatica101/API_SEGURITY_EXAMPLE.git"
BACKEND_BRANCH="actualizacion_version"
BACKEND_DIR="$ROOT_DIR/src/Backend/API_SEGURITY_EXAMPLE"

ensure_backend_repo() {
  need_cmd git

  say "Backend: asegurando repo en: $BACKEND_DIR"
  say "  Repo : $BACKEND_REPO_URL"
  say "  Rama : $BACKEND_BRANCH"

  mkdir -p "$ROOT_DIR/src/Backend"

  # Si no es repo git, clonar (si está vacío) o abortar (si no está vacío)
  if [[ ! -d "$BACKEND_DIR/.git" ]]; then
    if [[ -d "$BACKEND_DIR" ]] && [[ -n "$(ls -A "$BACKEND_DIR" 2>/dev/null || true)" ]]; then
      warn "La carpeta existe y no está vacía, pero no es un repo git:"
      warn "  $BACKEND_DIR"
      err "No la borro automáticamente para no perder datos. Muévela/bórrala y reintenta."
      exit 1
    fi
    rm -rf "$BACKEND_DIR" 2>/dev/null || true

    say "Clonando backend..."
    git clone --branch "$BACKEND_BRANCH" --single-branch "$BACKEND_REPO_URL" "$BACKEND_DIR"
    ok "Backend clonado."
    return 0
  fi

  # Ya es repo: actualizar
  say "Actualizando backend (fetch + checkout + pull)..."
  (
    cd "$BACKEND_DIR"

    # Asegurar remoto origin correcto
    local current_url
    current_url="$(git remote get-url origin 2>/dev/null || true)"
    if [[ -n "$current_url" && "$current_url" != "$BACKEND_REPO_URL" ]]; then
      warn "origin apunta a $current_url, lo cambio a $BACKEND_REPO_URL"
      git remote set-url origin "$BACKEND_REPO_URL"
    elif [[ -z "$current_url" ]]; then
      git remote add origin "$BACKEND_REPO_URL"
    fi

    git fetch --all --prune

    # Checkout rama destino (creándola si hace falta)
    if git show-ref --verify --quiet "refs/heads/$BACKEND_BRANCH"; then
      git checkout "$BACKEND_BRANCH"
    else
      git checkout -b "$BACKEND_BRANCH" "origin/$BACKEND_BRANCH" 2>/dev/null || git checkout "$BACKEND_BRANCH"
    fi

    # Configurar upstream y hacer pull
    git branch --set-upstream-to="origin/$BACKEND_BRANCH" "$BACKEND_BRANCH" >/dev/null 2>&1 || true
    git pull --ff-only || warn "No pude hacer pull --ff-only (puede haber cambios locales). Revisa con: git status"
  )
  ok "Backend actualizado."
}

check_backend_build_files() {
  if [[ ! -f "$BACKEND_DIR/pom.xml" ]] && [[ ! -f "$BACKEND_DIR/build.gradle" ]] && [[ ! -f "$BACKEND_DIR/build.gradle.kts" ]]; then
    err "El backend no parece un proyecto Maven/Gradle (no veo pom.xml ni build.gradle) en: $BACKEND_DIR"
    err "Contenido actual:"
    ls -la "$BACKEND_DIR" || true
    exit 1
  fi
}

# -----------------------------
# Raspberry Pi: instalación de dependencias
# -----------------------------
is_raspberry_pi() {
  [[ -f /proc/device-tree/model ]] && grep -qi "raspberry pi" /proc/device-tree/model
}

require_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -v
    else
      err "Necesitas sudo pero no está instalado."
      exit 1
    fi
  fi
}

install_docker_debian() {
  require_sudo
  say "Instalando Docker Engine (Debian/Raspberry Pi OS) + Compose v2 plugin..."

  # Paquetes base
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release uidmap git

  # Repo oficial Docker
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local codename
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-bookworm}")"

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    ${codename} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -y

  # Docker + compose plugin
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Servicio
  sudo systemctl enable --now docker

  # Grupo docker (para no usar sudo con docker)
  if ! getent group docker >/dev/null 2>&1; then
    sudo groupadd docker || true
  fi
  sudo usermod -aG docker "$USER" || true

  ok "Docker instalado. (OJO) Necesitas cerrar sesión y volver a entrar para aplicar el grupo 'docker'."
  say "Verificación:"
  docker version || true
  docker compose version || true
}

# Parche opcional para mismatch de API (cuando conectas a un daemon viejo/remoto)
apply_api_compat_patch() {
  warn "Aplicando compatibilidad DOCKER_API_VERSION=1.41 solo para esta ejecución..."
  export DOCKER_API_VERSION=1.41
}

# -----------------------------
# Detectar compose disponible
# -----------------------------
detect_compose() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return 0
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return 0
  fi
  if command -v podman-compose >/dev/null 2>&1; then
    echo "podman-compose"
    return 0
  fi
  return 1
}

COMPOSE_BIN="$(detect_compose || true)"

compose() {
  cd_root
  # shellcheck disable=SC2086
  $COMPOSE_BIN -f "$COMPOSE_FILE" "$@"
}

compose_services() {
  compose config --services 2>/dev/null || true
}

service_exists() {
  local svc="$1"
  compose_services | grep -Fxq "$svc"
}

# -----------------------------
# Comandos principales
# -----------------------------
cmd_setup() {
  if ! is_raspberry_pi; then
    warn "No parece Raspberry Pi, pero intentaré instalación Debian-compatible igualmente."
  fi

  install_docker_debian

  ok "Setup terminado."
  warn "IMPORTANTE: cierra sesión y vuelve a entrar, o ejecuta: newgrp docker"
  warn "Luego prueba: docker ps"
}

cmd_fetch_backend() {
  ensure_backend_repo
  check_backend_build_files
  ok "Backend listo para build."
}

cmd_up_all() {
  if [[ -z "${COMPOSE_BIN:-}" ]]; then
    err "No tienes Docker Compose instalado."
    err "Ejecuta: ./main.sh setup"
    exit 1
  fi

  # Traer/actualizar el backend automáticamente antes del build
  cmd_fetch_backend

  say "Levantando TODO con Compose -> ($COMPOSE_BIN)"
  say "Puertos esperados:"
  echo "  Backend   : http://localhost:9091"
  echo "  Frontend  : http://localhost:8081"
  echo "  Swagger UI: http://localhost:8083"
  echo "  MySQL     : localhost:3306"
  echo

  # Si vienes del error de API, puedes descomentar esta línea o usar DOCKER_API_VERSION=1.41
  # apply_api_compat_patch

  if ! compose down --remove-orphans; then
    warn "compose down devolvió error (normal si no había nada levantado)."
  fi

  compose up -d --build

  ok "Listo."
  print_access_urls
}

cmd_down_all() {
  if [[ -z "${COMPOSE_BIN:-}" ]]; then
    err "No tienes Docker Compose instalado."
    exit 1
  fi
  say "Parando todo -> ($COMPOSE_BIN down)"
  compose down --remove-orphans
  ok "Todo parado"
}

cmd_reset() {
  if [[ -z "${COMPOSE_BIN:-}" ]]; then
    err "No tienes Docker Compose instalado."
    exit 1
  fi
  warn "RESET: borra volumen MySQL (pierdes datos) y vuelve a levantar."
  compose down -v --remove-orphans
  compose up -d --build
  ok "Reset completo"
  print_access_urls
}

cmd_info() {
  say "Contexto Docker / versiones:"
  echo "DOCKER_HOST=${DOCKER_HOST:-<vacío>}"
  docker context show 2>/dev/null || true
  docker version || true
  docker compose version 2>/dev/null || true
  echo
  say "IP privada detectada:"
  local ip
  ip="$(get_private_ip || true)"
  if [[ -n "${ip:-}" ]]; then
    ok "  ${ip}"
  else
    warn "  (no detectada)"
  fi
}

usage() {
  cat <<'EOF'
Uso:
  ./main.sh setup          Instala Docker + Compose v2 (Raspberry Pi / Debian)
  ./main.sh fetch-backend  Clona/actualiza el backend (API_SEGURITY_EXAMPLE) rama actualizacion_version
  ./main.sh up             Trae backend y levanta todo (docker compose up -d --build)
  ./main.sh down           Para todo
  ./main.sh reset          Borra volúmenes (MySQL) y levanta de nuevo
  ./main.sh info           Muestra versiones y contexto docker (incluye IP privada)

Extra:
  Si te sale error de API "client version ... too new; max 1.41":
    DOCKER_API_VERSION=1.41 ./main.sh up
EOF
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    setup)        cmd_setup "$@" ;;
    fetch-backend) cmd_fetch_backend "$@" ;;
    up)           cmd_up_all "$@" ;;
    down)         cmd_down_all "$@" ;;
    reset)        cmd_reset "$@" ;;
    info)         cmd_info "$@" ;;
    ""|-h|--help|help) usage ;;
    *) err "Comando desconocido: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
