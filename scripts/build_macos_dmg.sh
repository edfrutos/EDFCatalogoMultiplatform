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

# ── 2b. Copiar .app a /tmp/ antes de firmar ───────────────────────────────────
# codesign falla con rutas que contienen caracteres NFD (acentos) en discos
# externos (HFS+/ExFAT). Copiamos a APFS local para que codesign opere sin
# problemas de encoding. La firma se aplica sobre esta copia local.
TMP_SIGN_DIR="/tmp/edf_sign_$$"
mkdir -p "${TMP_SIGN_DIR}"
LOCAL_APP="${TMP_SIGN_DIR}/$(basename "${APP_PATH}")"
info "Copiando .app a /tmp/ para firma local..."
ditto "${APP_PATH}" "${LOCAL_APP}"
APP_PATH="${LOCAL_APP}"
# Limpiar el directorio temporal al salir (éxito o error)
trap 'rm -rf "${TMP_SIGN_DIR}"' EXIT

# ── 3. Firma ad-hoc ──────────────────────────────────────────────────────────
info "Aplicando firma ad-hoc (uso local)..."
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
# Leemos el nombre real del ejecutable desde Info.plist (PlistBuddy es más robusto
# que 'defaults read' con paths que contienen caracteres no-ASCII).
BINARY_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" \
               "${APP_PATH}/Contents/Info.plist" 2>/dev/null \
               || basename "${APP_PATH%.app}")"
BINARY_PATH="${APP_PATH}/Contents/MacOS/${BINARY_NAME}"
info "  Firmando binario: ${BINARY_NAME}"
if [ -e "${BINARY_PATH}" ]; then
  # Limpiar extended attributes antes de firmar (evita errores con binarios Flutter/DartVM)
  xattr -cr "${BINARY_PATH}" 2>/dev/null || true
  codesign --force --sign - "${BINARY_PATH}" 2>&1 \
    && info "  ✓ Binario firmado" \
    || warning "  No se pudo firmar ${BINARY_NAME} (binario con subcomponentes DartVM — no crítico)"
else
  warning "  Binario no encontrado en: ${BINARY_PATH}"
  info "  Contenido de Contents/MacOS/:"
  ls -la "${APP_PATH}/Contents/MacOS/" 2>&1 || true
fi

# 3d. Firmar el bundle .app completo con entitlements para que el sandbox funcione
# Se intenta primero con --deep (firma recursiva de subcomponentes);
# si falla con Bus error (conocido en algunos binarios Flutter grandes), se intenta sin --deep.
ENTITLEMENTS_PATH="$(dirname "$0")/../macos/Runner/Release.entitlements"
_sign_app() {
  local deep_flag="$1"
  if [ -f "${ENTITLEMENTS_PATH}" ]; then
    codesign --force ${deep_flag} --sign - --entitlements "${ENTITLEMENTS_PATH}" "${APP_PATH}" 2>&1
  else
    codesign --force ${deep_flag} --sign - "${APP_PATH}" 2>&1
  fi
}
info "  Firmando bundle .app..."
if _sign_app "--deep"; then
  info "  ✓ Bundle firmado (--deep)"
else
  warning "  codesign --deep falló — reintentando sin --deep"
  _sign_app "" || warning "  codesign falló — continuando sin firma completa (la app puede pedir permiso al abrirse)"
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
# Usamos create-vacío → attach → ditto → detach → convert
# para evitar que -srcfolder falle con "Recurso ocupado" al procesar
# archivos del .app que tienen locks/extended-attrs en discos externos.
info "Creando DMG..."
FINAL_DMG="${DIST_DIR}/${DMG_NAME}"

# Calcular tamaño: du -sm + 20% de margen + 20MB para metadatos HFS+
APP_SIZE_MB=$(du -sm "${APP_PATH}" | cut -f1)
DMG_SIZE_MB=$(( APP_SIZE_MB + APP_SIZE_MB / 5 + 20 ))
info "  Tamaño app: ${APP_SIZE_MB}MB → imagen: ${DMG_SIZE_MB}MB"

# path único para el DMG temporal (mktemp -u no crea el archivo, solo genera el nombre)
TMP_BASE="$(mktemp -u /tmp/edf_XXXXXX)"
TMP_DMG="${TMP_BASE}.dmg"

# 5a. Crear imagen HFS+ vacía con tamaño explícito
# (hdiutil agrega .dmg si el path no termina en extensión reconocida;
#  pasamos TMP_BASE sin .dmg para que el archivo resultante sea TMP_DMG)
hdiutil create -megabytes "${DMG_SIZE_MB}" \
    -volname "${VOL_NAME}" \
    -fs HFS+ \
    "${TMP_BASE}" 2>&1

# 5b. Montar en un punto fijo conocido
MOUNT_POINT="/Volumes/${VOL_NAME}"
hdiutil attach "${TMP_DMG}" \
    -mountpoint "${MOUNT_POINT}" \
    -noautoopen \
    -nobrowse 2>&1

# 5c. Copiar .app con ditto (respeta estructura bundle, más robusto que cp -R)
info "  Copiando .app al volumen..."
ditto "${APP_PATH}" "${MOUNT_POINT}/$(basename "${APP_PATH}")"
# Enlace a /Applications para el instalador drag-and-drop
ln -sf /Applications "${MOUNT_POINT}/Applications"

# 5d. Desmontar (sync primero para evitar flush incompleto)
sync
sleep 1
hdiutil detach "${MOUNT_POINT}" -force 2>&1

# 5e. Convertir de UDRW a UDZO (solo lectura, comprimido zlib-9)
info "  Comprimiendo DMG final..."
hdiutil convert "${TMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${FINAL_DMG}" 2>&1

# Limpiar temporal
rm -f "${TMP_DMG}"

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
