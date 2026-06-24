#!/usr/bin/env bash
# =============================================================================
# run_api_dev.sh — Arranca el servidor API Dart en modo desarrollo
#
# Uso:
#   chmod +x scripts/run_api_dev.sh
#   ./scripts/run_api_dev.sh
#
# Requisitos:
#   - Dart SDK instalado y en el PATH
#   - Archivo .env en la raíz del proyecto con MONGO_URI, MONGO_DB,
#     API_JWT_SECRET, y opcionalmente AWS_ACCESS_KEY_ID, etc.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_ROOT/api"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}▶ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }

# Cargar .env como variables de entorno del proceso
if [ -f "$PROJECT_ROOT/.env" ]; then
  info "Cargando .env..."
  set -o allexport
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +o allexport
else
  warning ".env no encontrado — asegúrate de tener MONGO_URI, MONGO_DB y API_JWT_SECRET configurados"
fi

# Instalar dependencias si no existen
if [ ! -d "$API_DIR/.dart_tool" ]; then
  info "Instalando dependencias Dart..."
  (cd "$API_DIR" && dart pub get)
fi

info "Iniciando API en http://localhost:${API_PORT:-8089}"
echo "  MongoDB: ${MONGO_DB:-'(no configurado)'}"
echo "  CORS origin: ${API_CORS_ORIGIN:-'*'}"
echo ""

cd "$API_DIR"
exec dart run bin/server.dart
