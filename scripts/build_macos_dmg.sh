#!/usr/bin/env bash
# =============================================================================
# build_macos_dmg.sh — Compilar EDF Catálogo para macOS y empaquetar en DMG
#
# Uso:
#   chmod +x scripts/build_macos_dmg.sh
#   ./scripts/build_macos_dmg.sh
#
# Requisitos:
#   - Flutter instalado y en el PATH
#   - Xcode instalado y con Command Line Tools
#   - hdiutil (incluido en macOS)
# =============================================================================

set -euo pipefail

# ── Configuración ────────────────────────────────────────────────────────────
APP_NAME="EDF Catálogo"
APP_BUNDLE="EDF Catálogo.app"        # nombre real del .app generado por Xcode
APP_BINARY="edfcatalogomultiplatform" # nombre interno del ejecutable Flutter
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
DMG_NAME="EDFCatalogo-${VERSION}.dmg"
DIST_DIR="dist"
BUILD_DIR="build/macos/Build/Products/Release"

# ── Colores ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}▶ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✖ $*${NC}"; exit 1; }

# ── Comprobaciones previas ────────────────────────────────────────────────────
command -v flutter >/dev/null 2>&1 || error "Flutter no encontrado en PATH"
command -v hdiutil >/dev/null 2>&1 || error "hdiutil no encontrado (¿estás en macOS?)"

info "EDF Catálogo v${VERSION} — build macOS release"
echo ""

# ── 1. Limpiar build anterior ─────────────────────────────────────────────────
info "Limpiando build anterior..."
flutter clean
flutter pub get

# ── 2. Compilar release macOS ────────────────────────────────────────────────
info "Compilando flutter build macos --release..."
flutter build macos --release

# Buscar el .app generado (puede tener el nombre del PRODUCT_NAME o el binario)
if [ -d "${BUILD_DIR}/${APP_BUNDLE}" ]; then
    APP_PATH="${BUILD_DIR}/${APP_BUNDLE}"
elif [ -d "${BUILD_DIR}/${APP_BINARY}.app" ]; then
    APP_PATH="${BUILD_DIR}/${APP_BINARY}.app"
    APP_BUNDLE="${APP_BINARY}.app"
else
    # Buscar cualquier .app en el directorio
    APP_PATH=$(find "${BUILD_DIR}" -maxdepth 1 -name "*.app" | head -1)
    [ -z "${APP_PATH}" ] && error "No se encontró ningún .app en ${BUILD_DIR}"
    APP_BUNDLE=$(basename "${APP_PATH}")
fi
info "App encontrada: ${APP_PATH}"

# ── 3. Firma ad-hoc ──────────────────────────────────────────────────────────
info "Aplicando firma ad-hoc (uso local)..."
codesign --deep --force --sign - "${APP_PATH}" 2>&1 || warning "codesign falló — continuando sin firma"

# ── 4. Preparar directorio de distribución ───────────────────────────────────
info "Preparando distribución en ${DIST_DIR}/..."
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# ── 5. Crear DMG con hdiutil ─────────────────────────────────────────────────
info "Creando DMG temporal..."
TMP_DMG="${DIST_DIR}/tmp_${DMG_NAME}"
FINAL_DMG="${DIST_DIR}/${DMG_NAME}"
STAGING_DIR="$(mktemp -d)"

# Copiar .app al staging
cp -R "${APP_PATH}" "${STAGING_DIR}/"
# Crear enlace simbólico a /Applications
ln -s /Applications "${STAGING_DIR}/Applications"

# Crear DMG escribible
hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    "${TMP_DMG}"

# Convertir a DMG comprimido de solo lectura
hdiutil convert "${TMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${FINAL_DMG}"

# Limpiar temporales
rm -f "${TMP_DMG}"
rm -rf "${STAGING_DIR}"

# ── 6. Resultado ──────────────────────────────────────────────────────────────
echo ""
info "✅ DMG creado correctamente:"
ls -lh "${FINAL_DMG}"
echo ""
echo -e "${GREEN}  Ubicación: $(pwd)/${FINAL_DMG}${NC}"
echo ""
echo "Para instalar: abre el DMG → arrastra '${APP_BUNDLE}' a Applications"
echo ""
warning "Nota: al ser ad-hoc (sin Developer ID), la primera vez que"
warning "abras la app en otro Mac tendrás que ir a:"
warning "  Preferencias del Sistema → Privacidad y Seguridad → Abrir de todas formas"
