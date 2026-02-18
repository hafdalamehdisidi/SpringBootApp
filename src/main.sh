#!/usr/bin/env bash
set -e

# pipefail solo si es bash
if [ -n "${BASH_VERSION:-}" ]; then
  set -o pipefail
fi

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; BLUE="\033[0;34m"; RESET="\033[0m"
say() { echo -e "${BLUE}==>${RESET} $*"; }
ok()  { echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err() { echo -e "${RED}✖${RESET} $*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "No existe el comando: $1"; exit 1; }
}

# -----------------------------
# Detectar raíz del proyecto
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
  ROOT_DIR="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/../docker-compose.yml" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  err "No encuentro docker-compose.yml ni en:"
  err "  $SCRIPT_DIR/docker-compose.yml"
  err "  $SCRIPT_DIR/../docker-compose.yml"
  exit 1
fi

COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
cd_root() { cd "$ROOT_DIR"; }

# -----------------------------
# Detectar comando compose disponible
# -----------------------------
detect_compose() {
  # 1) docker compose (v2)
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return 0
  fi

  # 2) docker-compose (v1)
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return 0
  fi

  # 3) podman-compose (por si acaso)
  if command -v podman-compose >/dev/null 2>&1; then
    echo "podman-compose"
    return 0
  fi

  return 1
}

COMPOSE_BIN="$(detect_compose || true)"
if [[ -z "${COMPOSE_BIN:-}" ]]; then
  err "No tienes Docker Compose instalado."
  err "Instala UNA de estas opciones:"
  err "  - Docker Compose v2: 'docker compose'"
  err "  - Docker Compose v1: 'docker-compose'"
  exit 1
fi

# Wrapper para ejecutar compose siempre desde la raíz
compose() {
  cd_root
  # shellcheck disable=SC2086
  $COMPOSE_BIN -f "$COMPOSE_FILE" "$@"
}

# -----------------------------
# Comandos
# -----------------------------
cmd_up_all() {
  say "Levantando TODO con Compose -> ($COMPOSE_BIN)"
  say "Puertos esperados:"
  echo "  Backend   : http://localhost:9091"
  echo "  Frontend  : http://localhost:8081"
  echo "  Swagger UI: http://localhost:8083"
  echo "  MySQL     : localhost:3306"
  echo

  # Baja primero para evitar conflictos
  compose down --remove-orphans >/dev/null 2>&1 || true

  compose up -d --build

  ok "Listo. Comprueba:"
  ok "  Frontend  : http://localhost:8081"
  ok "  Backend   : http://localhost:9091"
  ok "  Swagger UI: http://localhost:8083"
}

cmd_down_all() {
  say "Parando todo -> ($COMPOSE_BIN down)"
  compose down --remove-orphans
  ok "Todo parado"
}

cmd_reset() {
  warn "RESET: borra volumen MySQL (pierdes datos) y vuelve a levantar."
  compose down -v --remove-orphans
  compose up -d --build
  ok "Reset completo"
}

cmd_logs() {
  local svc="${1:-}"
  if [[ -z "$svc" ]]; then
    say "Logs (Ctrl+C para salir)"
    compose logs -f --tail=200
  else
    say "Logs de servicio: $svc (Ctrl+C para salir)"
    compose logs -f --tail=200 "$svc"
  fi
}

cmd_status() {
  say "ROOT: $ROOT_DIR"
  say "COMPOSE: $COMPOSE_BIN"
  say "COMPOSE_FILE: $COMPOSE_FILE"
  echo
  compose ps
}

help_menu() {
  cat <<EOF
Uso: ./main.sh <comando>

Todo:
  up-all            Levanta mysql + backend + frontend + swagger-ui (compose up -d --build)
  down-all          Para todo (compose down)
  reset             Down -v y vuelve a levantar (borra datos MySQL)
  status            Estado y rutas
  logs              Logs de todos
  logs <servicio>   Logs de un servicio (mysql|backend|frontend|swagger-ui)

Ejemplos:
  ./main.sh up-all
  ./main.sh status
  ./main.sh logs
  ./main.sh logs backend
  ./main.sh down-all
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    up-all)     cmd_up_all ;;
    down-all)   cmd_down_all ;;
    reset)      cmd_reset ;;
    status)     cmd_status ;;
    logs)       cmd_logs "${1:-}" ;;
    help|--help|-h|"") help_menu ;;
    *)
      err "Comando desconocido: $cmd"
      echo
      help_menu
      exit 1
      ;;
  esac
}

main "$@"

