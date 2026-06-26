#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Despliegue a producción (Vultr + Plesk)
#
# Qué hace:
#   1. Construye Flutter Web en release (local)
#   2. Sincroniza build/web/ al webroot de Plesk via rsync
#   3. En el servidor: actualiza el repo git y reinicia el contenedor API
#
# Requisitos locales:
#   - flutter en el PATH
#   - ssh configurado para root@208.76.221.20 (clave en ~/.ssh/)
#
# Primer despliegue (solo una vez en el servidor):
#   ssh root@208.76.221.20
#   git clone <repo_url> /opt/edfcatalogo
#   cd /opt/edfcatalogo && cp .env.example .env  # rellenar producción
#   docker compose -f docker/docker-compose.prod.yml up -d --build
#
# Uso habitual:
#   ./scripts/deploy.sh
#
# Solo ficheros web (sin rebuild de la API):
#   SKIP_API=1 ./scripts/deploy.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

SERVER="root@208.76.221.20"
SSH_PORT="2222"
WEBROOT="/var/www/vhosts/efjdefrutos.com/edfcat.efjdefrutos.com/httpdocs"
SERVER_REPO="/opt/edfcatalogo"
SKIP_API="${SKIP_API:-0}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}▶ $*${NC}"; }
step()  { echo -e "${CYAN}── $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $*${NC}"; }

echo ""
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}   EDF Catálogo — despliegue producción     ${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo ""

# ── 1. Build Flutter Web release ──────────────────────────────────────────────
step "Construyendo Flutter Web (release)..."
(cd "$PROJECT_ROOT" && flutter build web --release)
info "Build completado ✅"

# ── 2. Sincronizar ficheros estáticos al servidor ─────────────────────────────
step "Sincronizando build/web/ → $SERVER:$WEBROOT ..."
rsync -avz --delete \
  --exclude=".DS_Store" \
  -e "ssh -p $SSH_PORT" \
  "$PROJECT_ROOT/build/web/" \
  "$SERVER:$WEBROOT/"
info "Ficheros web sincronizados ✅"

# ── 3. Actualizar repo y reiniciar API en el servidor ─────────────────────────
if [ "$SKIP_API" = "1" ]; then
  warn "SKIP_API=1 — saltando actualización de la API"
else
  step "Actualizando repo y reiniciando API en el servidor..."
  ssh -p "$SSH_PORT" "$SERVER" bash <<EOF
    set -e
    cd "$SERVER_REPO"
    git pull --ff-only
    docker compose -f docker/docker-compose.prod.yml up -d --build api
    echo "API reiniciada"
    docker compose -f docker/docker-compose.prod.yml ps
EOF
  info "API actualizada ✅"
fi

# ── Resultado ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}✅ Despliegue completado${NC}"
echo -e "  ${BOLD}https://edfcat.efjdefrutos.com${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo ""
