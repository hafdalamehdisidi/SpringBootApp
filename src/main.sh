#!/usr/bin/env bash
# Fuerza bash aunque el usuario ejecute con sh:
if [ -z "${BASH_VERSION:-}" ]; then exec /usr/bin/env bash "$0" "$@"; fi
set -euo pipefail

# ============================================
# SpringBootApp - main.sh (ruta fija de backend)
#
# Estructura fija:
#   SpringBootApp/
#     docs/api/openapi.yaml
#     src/
#       Backend/API_SEGURITY_EXAMPLE/   <-- SIEMPRE AQUÍ
#       Frontend/
#
# Comandos:
#   ./main.sh up-all        -> MySQL + Backend(demo) + Frontend + Swagger UI
#   ./main.sh down-all      -> apaga todo
#   ./main.sh demo          -> backend demo foreground
#   ./main.sh status        -> estado
# ============================================

# --------- Colores ----------
GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; BLUE="\033[0;34m"; RESET="\033[0m"
say(){  echo -e "${BLUE}==>${RESET} $*"; }
ok(){   echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err(){  echo -e "${RED}✖${RESET} $*" >&2; }

need_cmd(){ command -v "$1" >/dev/null 2>&1 || { err "No existe el comando: $1"; exit 1; }; }
need_dir(){ [[ -d "$1" ]] || { err "No existe el directorio: $1"; exit 1; }; }
need_file(){ [[ -f "$1" ]] || { err "No existe el fichero: $1"; exit 1; }; }

docker_running(){ docker ps --format '{{.Names}}' | grep -qx "$1"; }

wait_for_port() {
  local port="$1" name="${2:-servicio}" tries="${3:-40}"
  local i=0
  while (( i < tries )); do
    if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
      exec 3<&- 3>&-
      ok "$name escuchando en $port"
      return 0
    fi
    sleep 0.5
    ((i++))
  done
  return 1
}

# --------- Paths ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../SpringBootApp/src
APP_DIR="$SCRIPT_DIR"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"                 # .../SpringBootApp

BACKEND_DIR="${APP_DIR}/Backend/API_SEGURITY_EXAMPLE"
FRONTEND_DIR="${APP_DIR}/Frontend"
OPENAPI_DIR="${PROJECT_DIR}/docs/api"
OPENAPI_FILE="${OPENAPI_DIR}/openapi.yaml"

# --------- Defaults ----------
BACKEND_PORT_DEFAULT="9091"
FRONTEND_PORT_DEFAULT="8081"
OPENAPI_UI_PORT_DEFAULT="8083"

# --------- PIDs / Logs (raíz del proyecto) ----------
BACKEND_PID_FILE="${PROJECT_DIR}/.backend.pid"
BACKEND_LOG_FILE="${PROJECT_DIR}/backend.log"
FRONTEND_PID_FILE="${PROJECT_DIR}/.frontend.pid"
FRONTEND_LOG_FILE="${PROJECT_DIR}/frontend.log"

# --------- MySQL docker run ----------
MYSQL_CONTAINER="springbootapp-mysql"
MYSQL_IMAGE="mysql:8"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"
MYSQL_DATABASE="${MYSQL_DATABASE:-springbootapp}"
MYSQL_USER="${MYSQL_USER:-app}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-app}"

# --------- Swagger UI ----------
OPENAPI_UI_CONTAINER="springbootapp-openapi-ui"

# -------------------------
# Validaciones backend (ruta fija)
# -------------------------
check_backend() {
  need_dir "$BACKEND_DIR"

  if [[ ! -f "$BACKEND_DIR/pom.xml" ]]; then
    err "Falta pom.xml en: $BACKEND_DIR"
    err "Tu backend debe estar completo (Maven/Spring Boot) dentro de esa carpeta."
    exit 1
  fi

  if [[ ! -d "$BACKEND_DIR/src/main/java" ]]; then
    err "Falta src/main/java en: $BACKEND_DIR"
    err "Parece que no está el código fuente del backend."
    exit 1
  fi
}

# -------------------------
# Maven (mvnw o mvn)
# -------------------------
maven_build() {
  check_backend
  if [[ -f "$BACKEND_DIR/mvnw" ]]; then
    (cd "$BACKEND_DIR" && chmod +x mvnw && ./mvnw -DskipTests clean package)
  else
    need_cmd mvn
    (cd "$BACKEND_DIR" && mvn -DskipTests clean package)
  fi
}

pick_jar() {
  local jar
  jar="$(ls -1 "$BACKEND_DIR"/target/*.jar 2>/dev/null | grep -v '\-plain\.jar$' | head -n 1 || true)"
  [[ -n "$jar" ]] || { err "No se encontró ningún .jar en $BACKEND_DIR/target. ¿Falló el build?"; exit 1; }
  echo "$jar"
}

# -------------------------
# MySQL
# -------------------------
mysql_up() {
  need_cmd docker

  if docker ps --format '{{.Names}}' | grep -qx "$MYSQL_CONTAINER"; then
    ok "MySQL ya está corriendo: $MYSQL_CONTAINER (localhost:${MYSQL_PORT})"
    return 0
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "$MYSQL_CONTAINER"; then
    say "Arrancando MySQL existente (docker start)..."
    docker start "$MYSQL_CONTAINER" >/dev/null
    ok "MySQL arrancado: $MYSQL_CONTAINER (localhost:${MYSQL_PORT})"
    return 0
  fi

  say "Creando y levantando MySQL con docker run..."
  docker run -d --name "$MYSQL_CONTAINER" \
    -p "${MYSQL_PORT}:3306" \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DATABASE" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    "$MYSQL_IMAGE" >/dev/null

  ok "MySQL listo: localhost:${MYSQL_PORT}"
  warn "DB=${MYSQL_DATABASE} USER=${MYSQL_USER} PASS=${MYSQL_PASSWORD} ROOTPASS=${MYSQL_ROOT_PASSWORD}"
}

mysql_down() {
  need_cmd docker
  if docker ps --format '{{.Names}}' | grep -qx "$MYSQL_CONTAINER"; then
    say "Parando MySQL: $MYSQL_CONTAINER"
    docker stop "$MYSQL_CONTAINER" >/dev/null
    ok "MySQL detenido"
  else
    warn "MySQL no estaba corriendo: $MYSQL_CONTAINER"
  fi
}

# -------------------------
# Backend (demo)
# -------------------------
backend_stop() {
  if [[ -f "$BACKEND_PID_FILE" ]]; then
    local pid; pid="$(cat "$BACKEND_PID_FILE")"
    say "Parando backend (PID ${pid})..."
    kill "$pid" 2>/dev/null || true
    rm -f "$BACKEND_PID_FILE"
    ok "Backend detenido"
  else
    warn "No hay PID de backend (${BACKEND_PID_FILE})."
  fi
}

backend_log() {
  [[ -f "$BACKEND_LOG_FILE" ]] && tail -f "$BACKEND_LOG_FILE" || warn "No existe el log: $BACKEND_LOG_FILE"
}

backend_start_bg_demo() {
  check_backend
  local port="${1:-$BACKEND_PORT_DEFAULT}"

  backend_stop || true

  say "Build backend (Maven) ..."
  maven_build

  local jar; jar="$(pick_jar)"
  say "Levantando BACKEND (demo) en background: puerto ${port}"
  say "Jar : $jar"
  say "Log : $BACKEND_LOG_FILE"
  say "URL : http://localhost:${port}"

  nohup bash -c "exec java -jar \"$jar\" --spring.profiles.active=demo --server.port=${port}" \
    >"$BACKEND_LOG_FILE" 2>&1 &

  echo $! > "$BACKEND_PID_FILE"
  ok "Backend PID: $(cat "$BACKEND_PID_FILE")"

  if ! wait_for_port "$port" "Backend" 60; then
    warn "El backend NO abrió el puerto ${port}. Mira el log:"
    tail -n 200 "$BACKEND_LOG_FILE" || true
    exit 1
  fi
}

demo_fg() {
  check_backend
  local port="${1:-$BACKEND_PORT_DEFAULT}"
  say "Arrancando BACKEND (demo) en foreground: puerto ${port}"
  mysql_up || true
  maven_build
  local jar; jar="$(pick_jar)"
  exec java -jar "$jar" --spring.profiles.active=demo --server.port="$port"
}

# -------------------------
# Frontend
# -------------------------
frontend_stop() {
  if [[ -f "$FRONTEND_PID_FILE" ]]; then
    local pid; pid="$(cat "$FRONTEND_PID_FILE")"
    say "Parando frontend (PID ${pid})..."
    kill "$pid" 2>/dev/null || true
    rm -f "$FRONTEND_PID_FILE"
    ok "Frontend detenido"
  else
    warn "No hay PID de frontend (${FRONTEND_PID_FILE})."
  fi
}

frontend_log() {
  [[ -f "$FRONTEND_LOG_FILE" ]] && tail -f "$FRONTEND_LOG_FILE" || warn "No existe el log: $FRONTEND_LOG_FILE"
}

frontend_start_bg() {
  need_dir "$FRONTEND_DIR"
  local port="${1:-$FRONTEND_PORT_DEFAULT}"

  frontend_stop || true

  say "Levantando FRONTEND en background (python http.server) puerto ${port}"
  say "Log : $FRONTEND_LOG_FILE"
  say "URL : http://localhost:${port}"

  nohup bash -c "cd \"$FRONTEND_DIR\" && python3 -m http.server \"$port\"" \
    >"$FRONTEND_LOG_FILE" 2>&1 &
  echo $! > "$FRONTEND_PID_FILE"
  ok "Frontend PID: $(cat "$FRONTEND_PID_FILE")"
}

# -------------------------
# Swagger UI
# -------------------------
openapi_ui() {
  need_cmd docker
  need_dir "$OPENAPI_DIR"
  need_file "$OPENAPI_FILE"
  local port="${1:-$OPENAPI_UI_PORT_DEFAULT}"

  if docker_running "$OPENAPI_UI_CONTAINER"; then
    warn "Swagger UI ya estaba ejecutándose. Reiniciando..."
    docker rm -f "$OPENAPI_UI_CONTAINER" >/dev/null || true
  fi

  say "Levantando Swagger UI en http://localhost:${port}"
  docker run -d --rm \
    --name "$OPENAPI_UI_CONTAINER" \
    -p "${port}:8080" \
    -e SWAGGER_JSON=/spec/openapi.yaml \
    -v "${OPENAPI_DIR}:/spec:ro" \
    swaggerapi/swagger-ui >/dev/null

  ok "Swagger UI listo: http://localhost:${port}"
  ok "Spec: $OPENAPI_FILE"
}

openapi_stop() {
  need_cmd docker
  if docker_running "$OPENAPI_UI_CONTAINER"; then
    say "Parando Swagger UI..."
    docker rm -f "$OPENAPI_UI_CONTAINER" >/dev/null || true
    ok "Swagger UI detenido"
  else
    warn "Swagger UI no estaba ejecutándose"
  fi
}

# -------------------------
# UP / DOWN
# -------------------------
up_all() {
  local fport="${1:-$FRONTEND_PORT_DEFAULT}"
  local uiport="${2:-$OPENAPI_UI_PORT_DEFAULT}"
  local bport="${3:-$BACKEND_PORT_DEFAULT}"

  say "Levantando TODO: MySQL + Backend(demo) + Frontend + Swagger UI"
  say "Puertos: backend=${bport} | frontend=${fport} | swagger-ui=${uiport}"

  mysql_up
  backend_start_bg_demo "$bport"
  frontend_start_bg "$fport"
  openapi_ui "$uiport"

  ok "TODO levantado:"
  ok "  Backend   : http://localhost:${bport} (demo) | log: $BACKEND_LOG_FILE"
  ok "  Frontend  : http://localhost:${fport}       | log: $FRONTEND_LOG_FILE"
  ok "  Swagger UI: http://localhost:${uiport}"
  ok "  MySQL     : localhost:${MYSQL_PORT} (container: $MYSQL_CONTAINER)"
}

down_all() {
  say "Apagando TODO..."
  backend_stop || true
  frontend_stop || true
  openapi_stop || true
  mysql_down || true
  ok "Todo apagado"
}

status() {
  say "Rutas:"
  echo "  PROJECT   : $PROJECT_DIR"
  echo "  BACKEND   : $BACKEND_DIR"
  echo "  FRONTEND  : $FRONTEND_DIR"
  echo "  OPENAPI   : $OPENAPI_FILE"
  echo
  say "Defaults:"
  echo "  BACKEND_PORT  : $BACKEND_PORT_DEFAULT"
  echo "  FRONTEND_PORT : $FRONTEND_PORT_DEFAULT"
  echo "  SWAGGER_UI    : $OPENAPI_UI_PORT_DEFAULT"
  echo "  MYSQL_PORT    : $MYSQL_PORT"
  echo
  say "Estado:"
  [[ -f "$BACKEND_PID_FILE" ]] && ok "Backend BG PID: $(cat "$BACKEND_PID_FILE")" || warn "Backend BG: no"
  [[ -f "$FRONTEND_PID_FILE" ]] && ok "Frontend BG PID: $(cat "$FRONTEND_PID_FILE")" || warn "Frontend BG: no"
  docker_running "$OPENAPI_UI_CONTAINER" && ok "Swagger UI: running" || warn "Swagger UI: stopped"
  docker ps --format '{{.Names}}' | grep -qx "$MYSQL_CONTAINER" && ok "MySQL: running" || warn "MySQL: stopped"
}

help_menu() {
  cat <<EOF
Uso: ./main.sh <comando> [opciones]

TODO:
  up-all [fport] [uiport] [bport]   Defaults: 8081 8083 9091
  down-all
  status

Backend:
  demo [puerto]        Backend demo foreground (default 9091)
  backend-log          Ver log del backend BG
  backend-stop         Detener backend BG

Frontend:
  frontend-log         Ver log del frontend BG
  frontend-stop        Detener frontend BG

OpenAPI:
  openapi-ui [puerto]  Swagger UI (default 8083)
  openapi-stop         Detener Swagger UI
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    up-all)        up_all "${1:-$FRONTEND_PORT_DEFAULT}" "${2:-$OPENAPI_UI_PORT_DEFAULT}" "${3:-$BACKEND_PORT_DEFAULT}" ;;
    down-all)      down_all ;;
    status)        status ;;

    demo)          demo_fg "${1:-$BACKEND_PORT_DEFAULT}" ;;
    backend-log)   backend_log ;;
    backend-stop)  backend_stop ;;

    frontend-log)  frontend_log ;;
    frontend-stop) frontend_stop ;;

    openapi-ui)    openapi_ui "${1:-$OPENAPI_UI_PORT_DEFAULT}" ;;
    openapi-stop)  openapi_stop ;;

    help|--help|-h|"") help_menu ;;
    *) err "Comando desconocido: $cmd"; echo; help_menu; exit 1 ;;
  esac
}

main "$@"

