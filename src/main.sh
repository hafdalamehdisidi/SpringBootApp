#!/usr/bin/env bash
set -eu

# ============================================
# SpringBootApp - main.sh (Docker-first)
# ============================================
# Requisitos:
#   - docker y docker compose
#   - docker-compose.yml en la raíz del proyecto (../docker-compose.yml)
#
# Comandos:
#   ./main.sh up-all        -> Levanta mysql + backend + frontend + swagger-ui
#   ./main.sh down-all      -> Para todo
#   ./main.sh reset         -> down -v + up --build
#   ./main.sh status        -> Estado
#   ./main.sh logs          -> logs -f (todos)
#   ./main.sh logs backend  -> logs -f del servicio
#
# Puertos por defecto:
#   backend=9091, frontend=8081, swagger-ui=8083, mysql=3306
# ============================================

# --- Colors ---
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; BLUE="\033[0;34m"; RESET="\033[0m"
say() { echo -e "${BLUE}==>${RESET} $*"; }
ok()  { echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err() { echo -e "${RED}✖${RESET} $*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "No existe el comando: $1"; exit 1; }
}

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"         # .../SpringBootApp/src
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"         # .../SpringBootApp
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

# Defaults (solo informativos; los puertos reales los define docker-compose.yml)
BACKEND_PORT_DEFAULT="9091"
FRONTEND_PORT_DEFAULT="8081"
SWAGGER_PORT_DEFAULT="8083"
MYSQL_PORT_DEFAULT="3306"

compose() {
  need_cmd docker
  # docker compose (plugin) o docker-compose (legacy)
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" "$@"
  else
    need_cmd docker-compose
    docker-compose -f "$COMPOSE_FILE" "$@"
  fi
}

check_compose_file() {
  if [ ! -f "$COMPOSE_FILE" ]; then
    err "No encuentro docker-compose.yml en: $COMPOSE_FILE"
    err "Solución: crea el archivo en la raíz del proyecto (SpringBootApp/docker-compose.yml)."
    exit 1
  fi
}

urls() {
  echo "  Backend   : http://localhost:${BACKEND_PORT_DEFAULT}"
  echo "  Frontend  : http://localhost:${FRONTEND_PORT_DEFAULT}"
  echo "  Swagger UI: http://localhost:${SWAGGER_PORT_DEFAULT}"
  echo "  MySQL     : localhost:${MYSQL_PORT_DEFAULT}"
}

up_all() {
  check_compose_file
  say "Levantando TODO con Docker Compose..."
  say "Puertos esperados:"
  urls
  echo

  compose up -d --build

  ok "Listo."
  urls
  echo
  say "Si algo falla, mira logs:"
  echo "  ./main.sh logs"
  echo "  ./main.sh logs backend"
  echo "  ./main.sh logs mysql"
}

down_all() {
  check_compose_file
  say "Parando TODO..."
  compose down
  ok "Todo detenido."
}

reset_all() {
  check_compose_file
  warn "Esto hace down -v (borra volumen de MySQL)."
  say "Reseteando TODO..."
  compose down -v
  compose up -d --build
  ok "Reset completado."
  urls
}

status() {
  check_compose_file
  say "Proyecto:"
  echo "  SRC       : $SCRIPT_DIR"
  echo "  ROOT      : $PROJECT_DIR"
  echo "  COMPOSE   : $COMPOSE_FILE"
  echo
  say "Puertos esperados:"
  urls
  echo
  say "Estado docker compose:"
  compose ps || true
}

logs_all() {
  check_compose_file
  say "Logs (Ctrl+C para salir)"
  compose logs -f --tail=200
}

logs_service() {
  check_compose_file
  svc="${1:-}"
  if [ -z "$svc" ]; then
    logs_all
    return 0
  fi
  say "Logs de servicio: $svc (Ctrl+C para salir)"
  compose logs -f --tail=200 "$svc"
}

help_menu() {
  cat <<EOF
Uso: ./main.sh <comando>

Todo:
  up-all            Levanta mysql + backend + frontend + swagger-ui (docker compose up -d --build)
  down-all          Para todo (docker compose down)
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
  cmd="${1:-help}"
  shift || true

  case "$cmd" in
    up-all)     up_all ;;
    down-all)   down_all ;;
    reset)      reset_all ;;
    status)     status ;;
    logs)       logs_service "${1:-}" ;;
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

