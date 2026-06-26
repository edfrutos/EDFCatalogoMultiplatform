#!/usr/bin/env bash
# =============================================================================
# dev_tailscale.sh — Arranca API + Flutter Web y configura Tailscale Serve
#
# Secuencia completa con un solo comando:
#   1. Arranca API Dart en puerto $API_PORT (por defecto 8089)
#   2. Arranca Flutter Web headless en puerto $WEB_PORT (por defecto 56001)
#   3. Configura Tailscale Serve:
#        /     → Flutter Web (puerto 56001)   — acceso al frontend
#        /api  → API Dart   (puerto 8089)     — llamadas de la app
#   4. Muestra la URL HTTPS de Tailscale para abrir en cualquier dispositivo
#
# Uso:
#   chmod +x scripts/dev_tailscale.sh
#   ./scripts/dev_tailscale.sh
#
# Reconectar a la sesión tmux después de cerrar la terminal:
#   tmux attach -t edf
#
# Ver ventanas: Ctrl+B  W  (dentro de tmux)
# Detener todo: tmux kill-session -t edf
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
command -v tmux      >/dev/null 2>&1 || { echo "tmux no encontrado. Instala: brew install tmux"; exit 1; }
command -v tailscale >/dev/null 2>&1 || { echo "tailscale no encontrado."; exit 1; }
command -v flutter   >/dev/null 2>&1 || { echo "flutter no encontrado."; exit 1; }
command -v dart      >/dev/null 2>&1 || { echo "dart no encontrado."; exit 1; }

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
  warning ".env no encontrado — asegúrate de tener MONGO_URI, MONGO_DB y API_JWT_SECRET"
fi

# ── Instalar dependencias API si faltan ───────────────────────────────────────
if [ ! -d "$PROJECT_ROOT/api/.dart_tool" ]; then
  step "Instalando dependencias Dart API..."
  (cd "$PROJECT_ROOT/api" && dart pub get)
fi

# ── Matar sesión tmux anterior si existe ─────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  warning "Sesión tmux '$SESSION' ya existe — reiniciando..."
  tmux kill-session -t "$SESSION"
  sleep 1
fi

# ── Crear sesión tmux con dos ventanas ───────────────────────────────────────
step "Creando sesión tmux '$SESSION'..."

# Ventana 0: API Dart
tmux new-session -d -s "$SESSION" -n "api" -x 220 -y 50
tmux send-keys -t "$SESSION:api" \
  "cd '$PROJECT_ROOT/api' && echo '▶ Arrancando API...' && dart run bin/server.dart" Enter

# Ventana 1: Flutter Web headless (sin Chrome, accesible desde otros dispositivos)
tmux new-window -t "$SESSION" -n "flutter"
tmux send-keys -t "$SESSION:flutter" \
  "cd '$PROJECT_ROOT' && echo '▶ Arrancando Flutter Web...' && flutter run -d web-server --web-port $WEB_PORT --web-hostname 0.0.0.0" Enter

# Esperar a que la API arranque antes de configurar Tailscale
step "Esperando que la API esté lista (máx 20s)..."
for i in $(seq 1 40); do
  if curl -sf "http://localhost:$API_PORT/api/health" >/dev/null 2>&1; then
    echo "  API lista ✅"
    break
  fi
  sleep 0.5
  if [ "$i" -eq 40 ]; then
    warning "API no respondió en 20s — continúa de todos modos"
  fi
done

# ── Configurar Tailscale Serve ────────────────────────────────────────────────
step "Configurando Tailscale Serve (puerto HTTPS $HTTPS_PORT)..."

# Ruta raíz → Flutter Web
tailscale serve --bg --https="$HTTPS_PORT" "$WEB_PORT" 2>/dev/null || \
  tailscale serve --bg --https="$HTTPS_PORT" "http://localhost:$WEB_PORT" 2>/dev/null || \
  warning "No se pudo configurar / → puerto $WEB_PORT (quizá ya existe)"

# Ruta /api → API Dart
# La app detecta automáticamente el host remoto (env_config.dart → Uri.base.origin)
# y llama a /api/* en el mismo host:puerto, que Tailscale enruta al backend local.
if tailscale serve --bg --https="$HTTPS_PORT" --set-path /api "http://localhost:$API_PORT" 2>/dev/null; then
  echo "  /api → :$API_PORT ✅"
else
  warning "Tu versión de Tailscale puede no soportar --set-path."
  warning "Prueba manualmente: tailscale serve --bg --https=$HTTPS_PORT --set-path /api http://localhost:$API_PORT"
  warning "O actualiza Tailscale: sudo softwareupdate --install tailscale"
fi

# ── Obtener URL pública de Tailscale ─────────────────────────────────────────
TAILSCALE_HOST=$(tailscale status --json 2>/dev/null | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || echo "")

echo ""
echo -e "${BOLD}════════════════════════════════════════════${NC}"
if [ -n "$TAILSCALE_HOST" ]; then
  echo -e "${BOLD}  URL de acceso:${NC}"
  echo -e "  ${GREEN}https://${TAILSCALE_HOST}:${HTTPS_PORT}${NC}"
else
  echo -e "${BOLD}  Consulta la URL con:  tailscale serve status${NC}"
fi
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo ""
echo "  Local (Chrome):    http://localhost:$WEB_PORT"
echo "  API local:         http://localhost:$API_PORT"
echo ""
echo "  tmux ventanas:"
echo "    Ctrl+B  W    — lista de ventanas"
echo "    Ctrl+B  D    — desconectar (servidores siguen corriendo)"
echo "    Ctrl+B  N/P  — siguiente/anterior ventana"
echo "    Ctrl+B  [    — scroll (q para salir)"
echo ""
echo "  Detener todo:    tmux kill-session -t $SESSION"
echo "  Reconectar:      tmux attach -t $SESSION"
echo ""

# Conectar a la sesión mostrando la ventana flutter
tmux select-window -t "$SESSION:flutter"
tmux attach -t "$SESSION"
