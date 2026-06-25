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
info "Compilando flutter build macos --release (firma ad-hoc)..."
# Desactivar code signing de Xcode pasando las variables con prefijo FLUTTER_XCODE_.
# El script aplica firma ad-hoc (codesign --sign -) en el paso 3.
FLUTTER_XCODE_CODE_SIGNING_REQUIRED=NO \
FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO \
FLUTTER_XCODE_CODE_SIGN_IDENTITY="-" \
FLUTTER_XCODE_DEVELOPMENT_TEAM="" \
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
# Nota: --deep falla en binarios grandes (Bus error).
# Firmamos de dentro hacia fuera: dylibs → frameworks → binario principal → .app

# 3a. Firmar dylibs sueltos dentro de Frameworks
# Usamos -exec en lugar de | while read para evitar problemas con nombres
# que contienen caracteres especiales (acentos, espacios) en encodings NFD/NFC.
find "${APP_PATH}/Contents/Frameworks" -name "*.dylib" \
  -exec codesign --force --sign - {} \; 2>&1 || true

# 3b. Firmar cada .framework (el ejecutable dentro, luego el bundle)
find "${APP_PATH}/Contents/Frameworks" -name "*.framework" -type d 2>/dev/null | while read -r fw; do
  # Firmar el binario interno si existe
  fw_bin="${fw}/$(basename "${fw%.framework}")"
  [ -f "$fw_bin" ] && codesign --force --sign - "$fw_bin" 2>&1 || true
  codesign --force --sign - "$fw" 2>&1 || true
done

# 3c. Firmar el binario principal de la app
# Leemos el nombre real del ejecutable desde Info.plist en vez de usar find,
# para evitar cualquier problema de encoding NFD/NFC con find en HFS+/APFS.
BINARY_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" \
               "${APP_PATH}/Contents/Info.plist" 2>/dev/null \
               || basename "${APP_PATH%.app}")"
BINARY_PATH="${APP_PATH}/Contents/MacOS/${BINARY_NAME}"
info "  Firmando binario: ${BINARY_NAME}"
if [ -e "${BINARY_PATH}" ]; then
  codesign --force --sign - "${BINARY_PATH}" 2>&1 \
    && info "  ✓ Binario firmado" \
    || warning "  No se pudo firmar ${BINARY_NAME}"
else
  warning "  Binario no encontrado en: ${BINARY_PATH}"
  info "  Contenido de Contents/MacOS/:"
  ls -la "${APP_PATH}/Contents/MacOS/" 2>&1 || true
fi

# 3d. Firmar el bundle .app completo con entitlements para que el sandbox funcione
ENTITLEMENTS_PATH="$(dirname "$0")/../macos/Runner/Release.entitlements"
if [ -f "${ENTITLEMENTS_PATH}" ]; then
  codesign --force --sign - --entitlements "${ENTITLEMENTS_PATH}" "${APP_PATH}" 2>&1 \
    || warning "codesign falló — continuando sin firma"
else
  codesign --force --sign - "${APP_PATH}" 2>&1 \
    || warning "codesign falló — continuando sin firma"
fi

# ── 4. Preparar directorio de distribución ───────────────────────────────────
info "Preparando distribución en ${DIST_DIR}/..."
# Nombre ASCII para el volumen del DMG — hdiutil puede fallar con caracteres
# no-ASCII (acentos) al escribir la cabecera del volumen HFS+.
VOL_NAME="EDFCatalogo-${VERSION}"
# Desmontar cualquier volumen residual con ese nombre
hdiutil detach "/Volumes/${VOL_NAME}" 2>/dev/null || true
hdiutil detach "/Volumes/${APP_NAME} ${VERSION}" 2>/dev/null || true
sleep 1
rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# ── 5. Crear DMG con hdiutil ─────────────────────────────────────────────────
info "Creando DMG temporal..."
FINAL_DMG="${DIST_DIR}/${DMG_NAME}"
STAGING_DIR="$(mktemp -d)"
# mktemp -u genera un path único sin crear el archivo, evitando colisiones con runs anteriores
TMP_DMG="$(mktemp -u /tmp/edf_XXXXXX.dmg)"

# Copiar .app al staging
cp -R "${APP_PATH}" "${STAGING_DIR}/"
# Crear enlace simbólico a /Applications
ln -s /Applications "${STAGING_DIR}/Applications"

# Crear DMG escribible (volname ASCII para evitar problemas de encoding HFS+)
hdiutil create \
    -volname "${VOL_NAME}" \
    -srcfolder "${STAGING_DIR}" \
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
