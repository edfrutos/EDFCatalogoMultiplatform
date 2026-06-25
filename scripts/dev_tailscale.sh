#!/usr/bin/env bash
# =============================================================================
# dev_tailscale.sh — Arranca API + Flutter Web en tmux para acceso via Tailscale
#
# Uso:
#   chmod +x scripts/dev_tailscale.sh
#   ./scripts/dev_tailscale.sh
#
# Acceso desde Tailscale:
#   tailscale serve --set-path /    56001   # Flutter Web
#   tailscale serve --set-path /api 8089    # API Dart
#
# Reconectar a la sesión tmux después de cerrar la terminal:
#   tmux attach -t edf
#
# Detener todo:
#   tmux kill-session -t edf
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SESSION="edf"
WEB_PORT="${WEB_PORT:-56001}"
API_PORT="${API_PORT:-8089}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}▶ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }

# ── Requisitos ────────────────────────────────────────────────────────────────
command -v tmux >/dev/null 2>&1 || { echo "tmux no encontrado. Instala: brew install tmux"; exit 1; }

# ── Cargar .env ───────────────────────────────────────────────────────────────
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -o allexport
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +o allexport
else
  warning ".env no encontrado"
fi

# ── Instalar dependencias API si faltan ───────────────────────────────────────
if [ ! -d "$PROJECT_ROOT/api/.dart_tool" ]; then
  info "Instalando dependencias Dart API..."
  (cd "$PROJECT_ROOT/api" && dart pub get)
fi

# ── Matar sesión anterior si existe ──────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  warning "Sesión tmux '$SESSION' ya existe — matando..."
  tmux kill-session -t "$SESSION"
  sleep 1
fi

# ── Crear sesión tmux con dos ventanas ───────────────────────────────────────
info "Creando sesión tmux '$SESSION'..."

# Ventana 0: API Dart
tmux new-session -d -s "$SESSION" -n "api" -x 220 -y 50
tmux send-keys -t "$SESSION:api" "cd '$PROJECT_ROOT/api' && dart run bin/server.dart" Enter

# Ventana 1: Flutter Web (web-server headless — sin Chrome, accesible via Tailscale)
tmux new-window -t "$SESSION" -n "flutter"
tmux send-keys -t "$SESSION:flutter" \
  "cd '$PROJECT_ROOT' && flutter run -d web-server --web-port $WEB_PORT --web-hostname 0.0.0.0" Enter

# ── Mostrar instrucciones ─────────────────────────────────────────────────────
echo ""
info "Sesión tmux '$SESSION' arrancada con 2 ventanas:"
echo "  api     → http://localhost:$API_PORT"
echo "  flutter → http://localhost:$WEB_PORT"
echo ""
echo "  Para exponer via Tailscale:"
echo "    tailscale serve --set-path /    $WEB_PORT"
echo "    tailscale serve --set-path /api $API_PORT"
echo ""
echo "  Reconectar:  tmux attach -t $SESSION"
echo "  Ver ventanas: Ctrl+B  W  (dentro de tmux)"
echo "  Detener todo: tmux kill-session -t $SESSION"
echo ""

# Conectar a la sesión (muestra la ventana flutter por defecto)
tmux select-window -t "$SESSION:flutter"
tmux attach -t "$SESSION"
