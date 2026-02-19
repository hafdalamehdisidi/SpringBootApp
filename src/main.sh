#!/usr/bin/env bash
set -euo pipefail

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; BLUE="\033[0;34m"; RESET="\033[0m"
say() { echo -e "${BLUE}==>${RESET} $*"; }
ok()  { echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}⚠${RESET} $*"; }
err() { echo -e "${RED}✖${RESET} $*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "No existe el comando: $1"; exit 1; }
}

# -----------------------------
# Detectar raíz del proyecto (subiendo directorios, incluyendo /)
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
# Detectar comando compose disponible
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

# Obtener servicios definidos en el compose
compose_services() {
  compose config --services 2>/dev/null || true
}

service_exists() {
  local svc="$1"
  compose_services | grep -Fxq "$svc"
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

  # Baja primero para evitar conflictos (si falla, avisamos pero seguimos)
  if ! compose down --remove-orphans; then
    warn "compose down devolvió error (puede ser normal si no había nada levantado)."
  fi

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
  local svc=""
  local lines="200"
  local save="1"        # por defecto: guarda en ROOT_DIR/log y muestra
  local save_only="0"
  local follow="1"      # por defecto: follow cuando se muestra en pantalla

  # Uso:
  #   ./main.sh logs
  #   ./main.sh logs backend
  #   ./main.sh logs backend -n 500
  #   ./main.sh logs backend --no-save
  #   ./main.sh logs backend --save-only
  #   ./main.sh logs backend --save-only --follow
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--lines)
        # consumimos valor si existe y no es otro flag
        if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
          lines="$2"
          shift
        else
          warn "Opción $1 sin valor numérico; se mantiene lines=$lines"
        fi
        shift
        ;;
      --no-save)
        save="0"
        shift
        ;;
      --save-only)
        save="1"
        save_only="1"
        follow="0"   # en save-only, por defecto NO follow (evita proceso infinito “invisible”)
        shift
        ;;
      --follow|-f)
        follow="1"
        shift
        ;;
      --no-follow)
        follow="0"
        shift
        ;;
      *)
        if [[ -z "$svc" ]]; then
          svc="$1"
        else
          warn "Argumento ignorado: $1"
        fi
        shift
        ;;
    esac
  done

  # Validar servicio si se especifica
  if [[ -n "$svc" ]] && ! service_exists "$svc"; then
    err "Servicio desconocido: '$svc'"
    say "Servicios disponibles:"
    compose_services | sed 's/^/  - /'
    exit 1
  fi

  local log_dir="$ROOT_DIR/log"
  local ts out
  ts="$(date +"%Y-%m-%d_%H-%M-%S")"
  out="$log_dir/${svc:-all}_$ts.log"

  if [[ -z "$svc" ]]; then
    say "Logs (Ctrl+C para salir)"
  else
    say "Logs de servicio: $svc (Ctrl+C para salir)"
  fi

  mkdir -p "$log_dir"

  # Construir args para compose logs
  local -a args
  args=(logs --tail="$lines")
  [[ "$follow" == "1" ]] && args+=(-f)
  [[ -n "$svc" ]] && args+=("$svc")

  if [[ "$save" == "1" ]]; then
    say "Guardando logs en: $out"

    if [[ "$save_only" == "1" ]]; then
      # Por defecto sin -f (ya ajustado). Si el usuario pidió --follow, se quedará corriendo y avisamos.
      if [[ "$follow" == "1" ]]; then
        warn "--save-only con --follow: esto NO termina solo. Para parar: Ctrl+C."
      fi
      compose "${args[@]}" > "$out"
    else
      compose "${args[@]}" | tee "$out"
    fi
  else
    compose "${args[@]}"
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
  up-all                 Levanta mysql + backend + frontend + swagger-ui (compose up -d --build)
  down-all               Para todo (compose down)
  reset                  Down -v y vuelve a levantar (borra datos MySQL)
  status                 Estado y rutas
  logs [svc] [opciones]  Logs (por defecto guarda en log/*.log y muestra)

Logs opciones:
  --lines N, -n N        Nº de líneas iniciales (por defecto 200)
  --no-save              No guarda fichero, solo muestra por pantalla
  --save-only            Guarda en fichero pero no imprime en pantalla (por defecto sin follow)
  --follow, -f           Follow (útil con --save-only si lo quieres “en vivo”)
  --no-follow            Desactiva follow

Ejemplos:
  ./main.sh up-all
  ./main.sh status
  ./main.sh logs
  ./main.sh logs backend
  ./main.sh logs backend -n 500
  ./main.sh logs backend --save-only
  ./main.sh logs backend --save-only --follow
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
    logs)       cmd_logs "$@" ;;
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

