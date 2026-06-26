#!/usr/bin/env bash
# =============================================================================
# dev_tailscale.sh — Build release + API Dart + Tailscale Serve
#
# Usa un build de release (no flutter run) porque el modo dev inyecta un
# WebSocket de debug que falla cuando el cliente no es localhost.
#
# Secuencia:
#   1. Arranca API Dart en tmux (ventana "api")
#   2. Construye Flutter Web --release y lo sirve con Python HTTP server
#      en tmux (ventana "web")
#   3. Configura Tailscale Serve:
#        /     → puerto 56001 (Flutter Web estático)
#        /api  → puerto 8089  (API Dart)
#   4. Muestra la URL HTTPS de Tailscale
#
# Para actualizar la app después de cambios en el código:
#   tmux attach -t edf  →  ventana "web"  →  Ctrl+C  →  flecha arriba  →  Enter
#
# Uso:
#   chmod +x scripts/dev_tailscale.sh && ./scripts/dev_tailscale.sh
#
# Reconectar: tmux attach -t edf
# Detener:    tmux kill-session -t edf
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SESSION="edf"
WEB_PORT="${WEB_PORT:-56001}"
API_PORT="${API_PORT:-8089}"
HTTPS_PORT="${HTTPS_PORT:-8443}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${GREEN}▶ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }
step()    { echo -e "${CYAN}── $*${NC}"; }

# ── Requisitos ────────────────────────────────────────────────────────────────
command -v tmux      >/dev/null 2>&1 || { echo "tmux no encontrado: brew install tmux"; exit 1; }
command -v tailscale >/dev/null 2>&1 || { echo "tailscale no encontrado."; exit 1; }
command -v flutter   >/dev/null 2>&1 || { echo "flutter no encontrado."; exit 1; }
command -v dart      >/dev/null 2>&1 || { echo "dart no encontrado."; exit 1; }
command -v python3   >/dev/null 2>&1 || { echo "python3 no encontrado."; exit 1; }

echo ""
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}   EDF Catálogo — arranque Tailscale        ${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo ""

# ── Cargar .env ───────────────────────────────────────────────────────────────
if [ -f "$PROJECT_ROOT/.env" ]; then
  step "Cargando .env..."
  set -o allexport
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +o allexport
else
  warning ".env no encontrado"
fi

# ── Instalar dependencias API si faltan ───────────────────────────────────────
if [ ! -d "$PROJECT_ROOT/api/.dart_tool" ]; then
  step "Instalando dependencias Dart API..."
  (cd "$PROJECT_ROOT/api" && dart pub get)
fi

# ── Build Flutter Web release ─────────────────────────────────────────────────
# Release build: sin WebSocket de debug, sin hot reload.
# Los dispositivos remotos (iPhone, iPad) no pueden conectar al WebSocket de
# debug que inyecta "flutter run", lo que deja la app en blanco.
step "Construyendo Flutter Web (release)..."
(cd "$PROJECT_ROOT" && flutter build web --release)
info "Build completado ✅"

# ── Matar sesión tmux anterior si existe ─────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  warning "Sesión tmux '$SESSION' ya existe — reiniciando..."
  tmux kill-session -t "$SESSION"
  sleep 1
fi

# ── Crear sesión tmux ─────────────────────────────────────────────────────────
step "Creando sesión tmux '$SESSION'..."

# Ventana 0: API Dart
tmux new-session -d -s "$SESSION" -n "api" -x 220 -y 50
tmux send-keys -t "$SESSION:api" \
  "cd '$PROJECT_ROOT/api' && echo '▶ Arrancando API en :$API_PORT...' && dart run bin/server.dart" Enter

# Ventana 1: servidor HTTP estático para el build de release
BUILD_DIR="$PROJECT_ROOT/build/web"
REBUILD_CMD="cd '$PROJECT_ROOT' && flutter build web --release && python3 -m http.server $WEB_PORT --bind 0.0.0.0 --directory '$BUILD_DIR'"
tmux new-window -t "$SESSION" -n "web"
tmux send-keys -t "$SESSION:web" \
  "echo '▶ Sirviendo build/web en :$WEB_PORT...' && python3 -m http.server $WEB_PORT --bind 0.0.0.0 --directory '$BUILD_DIR'" Enter

# ── Configurar Tailscale Serve ────────────────────────────────────────────────
step "Configurando Tailscale Serve (HTTPS :$HTTPS_PORT)..."

tailscale serve --bg --https="$HTTPS_PORT" "$WEB_PORT" 2>/dev/null || \
  tailscale serve --bg --https="$HTTPS_PORT" "http://localhost:$WEB_PORT" 2>/dev/null || \
  warning "  / → :$WEB_PORT ya configurado o error"

# Puerto HTTPS dedicado para la API (sin path routing).
# NOTA: Tailscale Serve con --set-path elimina el prefijo del path al hacer
# el proxy (/api/auth/login → /auth/login en el backend). Para evitarlo,
# usamos un puerto HTTPS separado (8444) donde el path llega intacto.
API_HTTPS_PORT="${API_HTTPS_PORT:-8444}"
tailscale serve --bg --https="$API_HTTPS_PORT" "$API_PORT" 2>/dev/null || \
  tailscale serve --bg --https="$API_HTTPS_PORT" "http://localhost:$API_PORT" 2>/dev/null || \
  warning "  API HTTPS :$API_HTTPS_PORT ya configurado o error"
info "  API HTTPS :$API_HTTPS_PORT → :$API_PORT ✅"

# ── URL de acceso ─────────────────────────────────────────────────────────────
TAILSCALE_HOST=$(tailscale status --json 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || echo "")

echo ""
echo -e "${BOLD}════════════════════════════════════════════${NC}"
if [ -n "$TAILSCALE_HOST" ]; then
  echo -e "  ${BOLD}Acceso desde iPhone/iPad:${NC}"
  echo -e "  ${GREEN}https://${TAILSCALE_HOST}:${HTTPS_PORT}${NC}"
else
  echo -e "  Consulta URL: ${CYAN}tailscale serve status${NC}"
fi
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo ""
echo "  Local:   http://localhost:$WEB_PORT"
echo "  API:     http://localhost:$API_PORT"
echo ""
echo "  Rebuild tras cambios en el código:"
echo "    tmux attach -t $SESSION → ventana 'web' → Ctrl+C → flecha↑ → Enter"
echo "  O desde terminal:  cd '$PROJECT_ROOT' && $REBUILD_CMD"
echo ""
echo "  tmux:"
echo "    Ctrl+B W  — lista ventanas     Ctrl+B D  — desconectar"
echo "    Ctrl+B 0  — ventana api        Ctrl+B 1  — ventana web"
echo ""
echo "  Detener todo:  tmux kill-session -t $SESSION"
echo ""

tmux select-window -t "$SESSION:web"
tmux attach -t "$SESSION"
