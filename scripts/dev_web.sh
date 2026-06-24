#!/usr/bin/env bash
# =============================================================================
# dev_web.sh — Arranca el servidor API + Flutter Web en paralelo
#
# Uso:
#   chmod +x scripts/dev_web.sh
#   ./scripts/dev_web.sh
#
# Detener todo: Ctrl+C (mata servidor API y flutter run)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_ROOT/api"
LOG_API="$PROJECT_ROOT/.api_dev.log"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}▶ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }

# ── Cargar .env ───────────────────────────────────────────────────────────────
if [ -f "$PROJECT_ROOT/.env" ]; then
  info "Cargando .env..."
  set -o allexport
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +o allexport
else
  warning ".env no encontrado"
fi

API_PORT="${API_PORT:-8089}"

# ── Instalar dependencias API si faltan ───────────────────────────────────────
if [ ! -d "$API_DIR/.dart_tool" ]; then
  info "Instalando dependencias Dart API..."
  (cd "$API_DIR" && dart pub get)
fi

# ── Matar procesos previos en el puerto ──────────────────────────────────────
PREV_PID=$(lsof -ti tcp:"$API_PORT" 2>/dev/null || true)
if [ -n "$PREV_PID" ]; then
  warning "Puerto $API_PORT en uso (PID $PREV_PID) — matando..."
  kill "$PREV_PID" 2>/dev/null || true
  sleep 1
fi

# ── Arrancar API en background ───────────────────────────────────────────────
info "Arrancando API en http://localhost:$API_PORT (log → .api_dev.log)"
(cd "$API_DIR" && dart run bin/server.dart) > "$LOG_API" 2>&1 &
API_PID=$!
echo -e "${CYAN}  API PID: $API_PID${NC}"

# Esperar a que el servidor esté listo (máx 15s)
echo -n "  Esperando servidor"
for i in $(seq 1 30); do
  if curl -sf "http://localhost:$API_PORT/api/health" >/dev/null 2>&1 || \
     curl -sf "http://localhost:$API_PORT/" >/dev/null 2>&1; then
    echo ""
    info "Servidor listo ✅"
    break
  fi
  echo -n "."
  sleep 0.5
done
echo ""

# ── Cleanup al salir (Ctrl+C) ────────────────────────────────────────────────
cleanup() {
  echo ""
  warning "Deteniendo servidor API (PID $API_PID)..."
  kill "$API_PID" 2>/dev/null || true
  info "Todo detenido."
  exit 0
}
trap cleanup INT TERM

# ── Arrancar Flutter Web ─────────────────────────────────────────────────────
info "Arrancando Flutter Web en Chrome..."
echo ""
cd "$PROJECT_ROOT"
flutter run -d chrome

# Si flutter termina limpiamente, limpiar también el servidor
cleanup
