#!/usr/bin/env bash
set -euo pipefail

# ============================================
# SpringBootApp - Script principal (educativo)
# Backend: Spring Boot + MySQL + JWT
# Backend port: 9091
# Backend path: ./Backend/API_SEGURITY_EXAMPLE
# Frontend: estático (Bootstrap) servido con Python
# OpenAPI: docs/api/openapi.yaml (Swagger UI / Editor via Docker)
# ============================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${ROOT_DIR}/Backend/API_SEGURITY_EXAMPLE"
FRONTEND_DIR="${ROOT_DIR}/Frontend"
OPENAPI_DIR="${ROOT_DIR}/docs/api"
OPENAPI_FILE="${OPENAPI_DIR}/openapi.yaml"

# Defaults
BACKEND_PORT_DEFAULT="9091"
FRONTEND_PORT_DEFAULT="8081"

# OpenAPI viewers
OPENAPI_UI_PORT_DEFAULT="8083"
OPENAPI_EDITOR_PORT_DEFAULT="8082"
OPENAPI_UI_CONTAINER="springbootapp-openapi-ui"
OPENAPI_EDITOR_CONTAINER="springbootapp-openapi-editor"

# Frontend background management
FRONTEND_PID_FILE="${ROOT_DIR}/.frontend.pid"
FRONTEND_LOG_FILE="${ROOT_DIR}/frontend.log"

# Colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

say() { echo -e "${BLUE}==>${RESET} $*"; }
ok()  { echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err() { echo -e "${RED}✖${RESET} $*" >&2; }

need_dir() {
  if [[ ! -d "$1" ]]; then
    err "No existe el directorio: $1"
    exit 1
  fi
}

need_file() {
  if [[ ! -f "$1" ]]; then
    err "No existe el fichero: $1"
    exit 1
  fi
}

docker_running() {
  docker ps --format '{{.Names}}' | grep -qx "$1"
}

# -------------------------
# Docker: MySQL solo
# -------------------------
docker_db_up() {
  need_dir "$BACKEND_DIR"
  say "Levantando SOLO MySQL (Docker)..."
  (cd "$BACKEND_DIR" && docker compose up -d mysql)
  ok "MySQL debería estar en localhost:3306 (si el compose publica 3306:3306)"
}

docker_db_down() {
  need_dir "$BACKEND_DIR"
  say "Parando SOLO MySQL (Docker)..."
  (cd "$BACKEND_DIR" && docker compose stop mysql)
  ok "MySQL detenido"
}

# -------------------------
# Docker: stack completo
# -------------------------
docker_up() {
  need_dir "$BACKEND_DIR"
  say "Levantando Docker (backend + mysql) desde: $BACKEND_DIR"
  (cd "$BACKEND_DIR" && docker compose up --build)
}

docker_up_bg() {
  need_dir "$BACKEND_DIR"
  say "Levantando Docker (backend + mysql) en background (-d) desde: $BACKEND_DIR"
  (cd "$BACKEND_DIR" && docker compose up -d --build)
  ok "Docker levantado en background"
  ok "Backend debería estar en http://localhost:${BACKEND_PORT_DEFAULT}"
}

docker_down() {
  need_dir "$BACKEND_DIR"
  say "Parando contenedores (docker compose down) desde: $BACKEND_DIR"
  (cd "$BACKEND_DIR" && docker compose down)
  ok "Contenedores detenidos"
}

docker_logs() {
  need_dir "$BACKEND_DIR"
  say "Logs de Docker (Ctrl+C para salir)"
  (cd "$BACKEND_DIR" && docker compose logs -f --tail=200)
}

docker_reset() {
  need_dir "$BACKEND_DIR"
  warn "Esto borra volúmenes (base de datos incluida)."
  say "Reseteando Docker: down -v + build + up"
  (cd "$BACKEND_DIR" && docker compose down -v)
  (cd "$BACKEND_DIR" && docker compose up --build)
}

# -------------------------
# Local (sin Docker)
# -------------------------
local_build() {
  need_dir "$BACKEND_DIR"
  say "Compilando en local con Maven Wrapper (sin Docker)"
  (cd "$BACKEND_DIR" && chmod +x mvnw && ./mvnw -DskipTests clean package)
  ok "Build local completado"
}

local_run() {
  need_dir "$BACKEND_DIR"
  local port="${1:-$BACKEND_PORT_DEFAULT}"

  say "Arrancando Spring Boot en local (sin Docker) en puerto ${port}"
  warn "Asegúrate de tener MySQL local en localhost:3306 o usa: ./main.sh db-up"

  export SERVER_PORT="$port"
  (cd "$BACKEND_DIR" && chmod +x mvnw && ./mvnw spring-boot:run)
}

local_run_profile() {
  need_dir "$BACKEND_DIR"
  local profile="${1:-demo}"
  local port="${2:-$BACKEND_PORT_DEFAULT}"

  say "Arrancando Spring Boot en local con perfil '${profile}' en puerto ${port}"
  warn "Si MySQL no está en localhost:3306, usa: ./main.sh db-up (Docker) o ajusta datasource."

  export SPRING_PROFILES_ACTIVE="$profile"
  export SERVER_PORT="$port"
  (cd "$BACKEND_DIR" && chmod +x mvnw && ./mvnw spring-boot:run)
}

# -------------------------
# Frontend (python server)
# -------------------------
frontend_up() {
  need_dir "$FRONTEND_DIR"
  local port="${1:-$FRONTEND_PORT_DEFAULT}"

  say "Levantando frontend estático con Python en: $FRONTEND_DIR"
  say "URL: http://localhost:${port}"
  warn "Pulsa Ctrl+C para detener el servidor"

  (cd "$FRONTEND_DIR" && python3 -m http.server "$port")
}

frontend_start_bg() {
  need_dir "$FRONTEND_DIR"
  local port="${1:-$FRONTEND_PORT_DEFAULT}"

  # Stop previous instance if any
  if [[ -f "$FRONTEND_PID_FILE" ]]; then
    frontend_stop || true
  fi

  say "Levantando frontend en background (python http.server) en puerto ${port}"
  say "URL: http://localhost:${port}"
  nohup bash -c "cd \"$FRONTEND_DIR\" && python3 -m http.server \"$port\"" \
    > "$FRONTEND_LOG_FILE" 2>&1 &

  echo $! > "$FRONTEND_PID_FILE"
  ok "Frontend PID: $(cat "$FRONTEND_PID_FILE")"
  ok "Log: $FRONTEND_LOG_FILE"
}

frontend_stop() {
  if [[ -f "$FRONTEND_PID_FILE" ]]; then
    local pid
    pid="$(cat "$FRONTEND_PID_FILE")"
    say "Parando frontend (PID ${pid})..."
    kill "$pid" 2>/dev/null || true
    rm -f "$FRONTEND_PID_FILE"
    ok "Frontend detenido"
  else
    warn "No hay PID de frontend (${FRONTEND_PID_FILE}). ¿Estaba levantado?"
  fi
}

frontend_log() {
  if [[ -f "$FRONTEND_LOG_FILE" ]]; then
    tail -f "$FRONTEND_LOG_FILE"
  else
    warn "No existe el log: $FRONTEND_LOG_FILE"
  fi
}

# -------------------------
# OpenAPI (Swagger UI / Editor)
# -------------------------
openapi_ui() {
  need_dir "$OPENAPI_DIR"
  need_file "$OPENAPI_FILE"
  local port="${1:-$OPENAPI_UI_PORT_DEFAULT}"

  # Stop existing container if running
  if docker_running "$OPENAPI_UI_CONTAINER"; then
    warn "Swagger UI ya estaba ejecutándose. Reiniciando..."
    docker rm -f "$OPENAPI_UI_CONTAINER" >/dev/null
  fi

  say "Levantando Swagger UI en http://localhost:${port}"
  docker run -d --rm \
    --name "$OPENAPI_UI_CONTAINER" \
    -p "${port}:8080" \
    -e SWAGGER_JSON=/spec/openapi.yaml \
    -v "${OPENAPI_DIR}:/spec:ro" \
    swaggerapi/swagger-ui >/dev/null

  ok "Swagger UI listo: http://localhost:${port}"
  ok "Usando spec: ${OPENAPI_FILE}"
}

openapi_editor() {
  local port="${1:-$OPENAPI_EDITOR_PORT_DEFAULT}"

  if docker_running "$OPENAPI_EDITOR_CONTAINER"; then
    warn "Swagger Editor ya estaba ejecutándose. Reiniciando..."
    docker rm -f "$OPENAPI_EDITOR_CONTAINER" >/dev/null
  fi

  say "Levantando Swagger Editor en http://localhost:${port}"
  docker run -d --rm \
    --name "$OPENAPI_EDITOR_CONTAINER" \
    -p "${port}:8080" \
    swaggerapi/swagger-editor >/dev/null

  ok "Swagger Editor listo: http://localhost:${port}"
  warn "Pega/arrastra tu YAML (docs/api/openapi.yaml) dentro del editor."
}

openapi_stop() {
  local stopped=false
  if docker_running "$OPENAPI_UI_CONTAINER"; then
    say "Parando Swagger UI..."
    docker rm -f "$OPENAPI_UI_CONTAINER" >/dev/null || true
    stopped=true
  fi
  if docker_running "$OPENAPI_EDITOR_CONTAINER"; then
    say "Parando Swagger Editor..."
    docker rm -f "$OPENAPI_EDITOR_CONTAINER" >/dev/null || true
    stopped=true
  fi

  if [[ "$stopped" == "true" ]]; then
    ok "OpenAPI viewers detenidos"
  else
    warn "No había viewers OpenAPI ejecutándose"
  fi
}

# -------------------------
# All-in-one: apagar y levantar todo
# -------------------------
reup() {
  need_dir "$BACKEND_DIR"
  say "Reiniciando stack Docker (backend + mysql)..."
  (cd "$BACKEND_DIR" && docker compose down)
  (cd "$BACKEND_DIR" && docker compose up -d --build)
  ok "Docker reup completado"
  ok "Backend: http://localhost:${BACKEND_PORT_DEFAULT}"
}

reup_all() {
  local fport="${1:-$FRONTEND_PORT_DEFAULT}"
  local oport="${2:-$OPENAPI_UI_PORT_DEFAULT}"

  say "Reiniciando TODO: Docker (backend+mysql) + frontend + Swagger UI"
  frontend_stop || true
  openapi_stop || true
  reup
  frontend_start_bg "$fport"
  openapi_ui "$oport"

  ok "TODO levantado:"
  ok "  Backend   : http://localhost:${BACKEND_PORT_DEFAULT}"
  ok "  Frontend  : http://localhost:${fport}"
  ok "  Swagger UI: http://localhost:${oport}"
}

down_all() {
  say "Apagando TODO: frontend + OpenAPI viewers + Docker"
  frontend_stop || true
  openapi_stop || true
  docker_down
  ok "Todo apagado"
}

# -------------------------
# Status / Help
# -------------------------
status() {
  say "Estructura detectada:"
  echo "  ROOT      : $ROOT_DIR"
  echo "  BACKEND   : $BACKEND_DIR"
  echo "  FRONTEND  : $FRONTEND_DIR"
  echo "  OPENAPI   : $OPENAPI_FILE"
  echo "  B.PORT    : $BACKEND_PORT_DEFAULT"
  echo "  F.PORT    : $FRONTEND_PORT_DEFAULT"
  echo "  UI.PORT   : $OPENAPI_UI_PORT_DEFAULT"
  echo "  EDIT.PORT : $OPENAPI_EDITOR_PORT_DEFAULT"
  echo

  say "Docker containers (stack backend/mysql):"
  (cd "$BACKEND_DIR" 2>/dev/null && docker compose ps) || warn "No se pudo ejecutar docker compose ps"
  echo

  if [[ -f "$FRONTEND_PID_FILE" ]]; then
    say "Frontend (background): PID $(cat "$FRONTEND_PID_FILE") | log $FRONTEND_LOG_FILE"
  else
    say "Frontend (background): no está levantado"
  fi
  echo

  say "OpenAPI viewers:"
  if docker_running "$OPENAPI_UI_CONTAINER"; then
    ok "Swagger UI: running (${OPENAPI_UI_CONTAINER})"
  else
    warn "Swagger UI: stopped"
  fi
  if docker_running "$OPENAPI_EDITOR_CONTAINER"; then
    ok "Swagger Editor: running (${OPENAPI_EDITOR_CONTAINER})"
  else
    warn "Swagger Editor: stopped"
  fi
}

help_menu() {
  cat <<EOF
Uso: ./main.sh <comando> [opciones]

Docker:
  docker-up                 Levanta backend + mysql (foreground)
  docker-up-bg              Levanta backend + mysql (background -d)
  docker-down               Para contenedores (docker compose down)
  docker-logs               Sigue logs (tail)
  docker-reset              Down -v (borra BD) y vuelve a levantar
  db-up                     Levanta SOLO MySQL (docker compose up -d mysql)
  db-down                   Para SOLO MySQL (docker compose stop mysql)

Local (sin Docker):
  build                     Compila (mvnw clean package)
  run [puerto]              Ejecuta Spring Boot en local (default: ${BACKEND_PORT_DEFAULT})
  run-profile <perfil> [p]  Ejecuta en local con perfil (ej: demo) y puerto opcional

Frontend:
  frontend [puerto]         Sirve ./Frontend con python (foreground)
  frontend-bg [puerto]      Sirve ./Frontend con python (background)
  frontend-stop             Detiene el frontend en background
  frontend-log              Muestra logs del frontend en background

OpenAPI (Docs):
  openapi-ui [puerto]       Levanta Swagger UI apuntando a docs/api/openapi.yaml (default: ${OPENAPI_UI_PORT_DEFAULT})
  openapi-editor [puerto]   Levanta Swagger Editor (default: ${OPENAPI_EDITOR_PORT_DEFAULT})
  openapi-stop              Detiene Swagger UI/Editor

Todo:
  reup                      Apaga y vuelve a levantar Docker (backend+mysql) en background
  reup-all [fport] [uiport] Apaga y vuelve a levantar Docker + frontend + Swagger UI
  down-all                  Apaga frontend, viewers OpenAPI y baja Docker

Otros:
  status                    Muestra rutas y estado docker/frontend/openapi
  help                      Muestra esta ayuda

Ejemplos:
  ./main.sh openapi-ui
  ./main.sh openapi-editor
  ./main.sh reup-all
  ./main.sh reup-all 8081 8083
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    # Docker
    docker-up)        docker_up ;;
    docker-up-bg)     docker_up_bg ;;
    docker-down)      docker_down ;;
    docker-logs)      docker_logs ;;
    docker-reset)     docker_reset ;;
    db-up)            docker_db_up ;;
    db-down)          docker_db_down ;;

    # Local
    build)            local_build ;;
    run)              local_run "${1:-$BACKEND_PORT_DEFAULT}" ;;
    run-profile)      local_run_profile "${1:-demo}" "${2:-$BACKEND_PORT_DEFAULT}" ;;

    # Frontend
    frontend)         frontend_up "${1:-$FRONTEND_PORT_DEFAULT}" ;;
    frontend-bg)      frontend_start_bg "${1:-$FRONTEND_PORT_DEFAULT}" ;;
    frontend-stop)    frontend_stop ;;
    frontend-log)     frontend_log ;;

    # OpenAPI
    openapi-ui)       openapi_ui "${1:-$OPENAPI_UI_PORT_DEFAULT}" ;;
    openapi-editor)   openapi_editor "${1:-$OPENAPI_EDITOR_PORT_DEFAULT}" ;;
    openapi-stop)     openapi_stop ;;

    # All-in-one
    reup)             reup ;;
    reup-all)         reup_all "${1:-$FRONTEND_PORT_DEFAULT}" "${2:-$OPENAPI_UI_PORT_DEFAULT}" ;;
    down-all)         down_all ;;

    # Misc
    status)           status ;;
    help|--help|-h)   help_menu ;;
    *)
      err "Comando desconocido: $cmd"
      echo
      help_menu
      exit 1
      ;;
  esac
}

main "$@"

