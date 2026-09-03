#!/usr/bin/env bash
# =============================================================================
# build_macos_dmg.sh — Compilar EDF Catálogo para macOS y empaquetar en DMG
#
# Uso:
#   chmod +x scripts/build_macos_dmg.sh
#   ./scripts/build_macos_dmg.sh [opciones]
#
# Opciones:
#   --adhoc            Fuerza firma ad-hoc (uso interno). Ignora MACOS_SIGN_IDENTITY.
#   --identity "..."   Identidad de firma Developer ID (override de $MACOS_SIGN_IDENTITY).
#                      Ej: "Developer ID Application: Nombre Apellidos (ABCDE12345)"
#   --skip-notarize    Firma con Developer ID pero NO envía a notarizar.
#   -h | --help        Muestra esta ayuda.
#
# Modo de firma (resolución automática):
#   - Si hay identidad Developer ID (--identity o $MACOS_SIGN_IDENTITY) y NO --adhoc:
#       → firma real + Hardened Runtime + firma del DMG + notarización + staple
#   - En cualquier otro caso:
#       → firma ad-hoc (comportamiento histórico; la app pide "Abrir de todas formas")
#
# Variables de entorno relevantes (ver docs/macos/DISTRIBUCION_MACOS.md):
#   MACOS_SIGN_IDENTITY   Identidad "Developer ID Application: ... (TEAMID)"
#   APPLE_TEAM_ID         Team ID de la cuenta Apple Developer
#   NOTARY_PROFILE        Nombre del perfil de llavero creado con
#                         `xcrun notarytool store-credentials`
#   NOTARY_API_KEY        (alternativa a NOTARY_PROFILE) ruta al AuthKey_XXXX.p8
#   NOTARY_API_KEY_ID     Key ID de la API Key de App Store Connect
#   NOTARY_API_ISSUER     Issuer ID de la API Key
#
# Requisitos:
#   - Flutter instalado y en el PATH
#   - Xcode instalado y con Command Line Tools
#   - hdiutil, codesign, xcrun (incluidos en macOS)
#   - Para firma real: certificado "Developer ID Application" en el llavero
# =============================================================================

set -euo pipefail

# ── Parámetros ──────────────────────────────────────────────────────────────
FORCE_ADHOC=0
SKIP_NOTARIZE=0
CLI_IDENTITY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --adhoc)         FORCE_ADHOC=1 ;;
    --skip-notarize) SKIP_NOTARIZE=1 ;;
    --identity)      CLI_IDENTITY="${2:-}"; shift ;;
    --identity=*)    CLI_IDENTITY="${1#*=}" ;;
    -h|--help)       sed -n '2,40p' "$0"; exit 0 ;;
    *)               echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done

# ── Configuración ────────────────────────────────────────────────────────────
# Bundle/binario en ASCII ("EDFCatalogo"): un nombre con acentos rompe
# `codesign --verify` en macOS 27 beta. El nombre visible ("EDF Catálogo") va
# en Info.plist → CFBundleDisplayName.
APP_NAME="EDFCatalogo"
APP_BUNDLE="EDFCatalogo.app"          # nombre real del .app generado por Xcode
APP_BINARY="edfcatalogomultiplatform" # nombre legacy del ejecutable Flutter
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

# ── Cargar variables de firma/notarización desde .env ──────────────────────
# El .env NO se sourcea en la shell; lo leemos aquí sólo para estas claves,
# y sólo si no vienen ya definidas en el entorno.
ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"
if [ -f "${ENV_FILE}" ]; then
  for _k in APPLE_TEAM_ID MACOS_SIGN_IDENTITY NOTARY_PROFILE \
            NOTARY_API_KEY NOTARY_API_KEY_ID NOTARY_API_ISSUER; do
    if [ -z "${!_k:-}" ]; then
      _v="$(sed -n "s/^[[:space:]]*${_k}=//p" "${ENV_FILE}" | head -1 | tr -d '\r' \
            | sed -e 's/^["'\'']//' -e 's/["'\'']$//')"
      [ -n "${_v}" ] && export "${_k}=${_v}"
    fi
  done
  [ -n "${APPLE_TEAM_ID:-}" ] && info "APPLE_TEAM_ID cargado de .env: ${APPLE_TEAM_ID}"
fi

# ── Resolver modo de firma ──────────────────────────────────────────────────
SIGN_IDENTITY=""
if [ "${FORCE_ADHOC}" -eq 0 ]; then
  SIGN_IDENTITY="${CLI_IDENTITY:-${MACOS_SIGN_IDENTITY:-}}"

  # Autoresolución: si no hay identidad explícita pero sí APPLE_TEAM_ID, buscar el
  # certificado "Developer ID Application" de ese Team en el llavero.
  # (No usamos el Team ID pelado como --sign porque también casaría con el cert
  #  "Developer ID Installer" del mismo Team → ambigüedad.)
  if [ -z "${SIGN_IDENTITY}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
      | grep '"Developer ID Application:' \
      | grep -F "(${APPLE_TEAM_ID})" \
      | head -1 \
      | sed -E 's/.*"(.*)".*/\1/')"
    [ -n "${SIGN_IDENTITY}" ] && info "Identidad autoresuelta desde APPLE_TEAM_ID: ${SIGN_IDENTITY}"
  fi
fi

if [ -n "${SIGN_IDENTITY}" ]; then
  SIGN_MODE="developer-id"
  # Comprobar que la identidad existe en el llavero
  if ! security find-identity -v -p codesigning 2>/dev/null | grep -qF "${SIGN_IDENTITY}"; then
    warning "La identidad indicada no aparece en 'security find-identity -v -p codesigning':"
    warning "  ${SIGN_IDENTITY}"
    warning "Continúo de todas formas — codesign fallará si no está disponible."
  fi
else
  SIGN_MODE="adhoc"
  if [ "${FORCE_ADHOC}" -eq 0 ]; then
    info "Sin identidad Developer ID (define MACOS_SIGN_IDENTITY o APPLE_TEAM_ID) → firma ad-hoc."
  fi
fi

info "EDF Catálogo v${VERSION} — build macOS release"
if [ "${SIGN_MODE}" = "developer-id" ]; then
  info "Modo de firma: Developer ID  →  ${SIGN_IDENTITY}"
  [ "${SKIP_NOTARIZE}" -eq 1 ] && warning "Notarización DESACTIVADA (--skip-notarize)"
else
  warning "Modo de firma: AD-HOC (uso interno). Usa --identity o \$MACOS_SIGN_IDENTITY para Developer ID."
fi
echo ""

# ── Helper de firma ─────────────────────────────────────────────────────────
# _cs <ruta> [args-extra...]
#   ad-hoc      → codesign --force --sign -
#   developer-id→ codesign --force --options runtime --timestamp --sign "<id>"
_cs() {
  local target="$1"; shift
  if [ "${SIGN_MODE}" = "developer-id" ]; then
    codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "$@" "${target}"
  else
    codesign --force --sign - "$@" "${target}"
  fi
}

# ── 1. Limpiar build anterior ─────────────────────────────────────────────────
info "Limpiando build anterior..."
flutter clean
flutter pub get

# ── 2. Compilar release macOS ────────────────────────────────────────────────
info "Compilando flutter build macos --release..."
# Desactivamos el code signing automático de Xcode; la firma (ad-hoc o Developer ID)
# se aplica manualmente en el paso 3 con orden inside-out y, si procede, Hardened Runtime.
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
# El proyecto vive en un disco EXTERNO (/Volumes/ESSAGER, posiblemente exFAT/HFS+).
# En esos FS cada fichero con xattrs/resource-fork tiene un compañero AppleDouble
# `._nombre`, y hay `.DS_Store` por doquier. `ditto` los copia como ficheros reales
# → acaban DENTRO del bundle → codesign los sella → al verificar:
# "a sealed resource is missing or invalid". Copiamos a APFS local y limpiamos.
TMP_SIGN_DIR="/tmp/edf_sign_$$"
mkdir -p "${TMP_SIGN_DIR}"
LOCAL_APP="${TMP_SIGN_DIR}/$(basename "${APP_PATH}")"
info "Copiando .app a /tmp/ para firma local..."
# --norsrc --noextattr --noacl: no arrastrar resource forks / xattrs / ACLs del FS externo
ditto --norsrc --noextattr --noacl "${APP_PATH}" "${LOCAL_APP}"
APP_PATH="${LOCAL_APP}"
# Limpiar el directorio temporal al salir (éxito o error)
trap 'rm -rf "${TMP_SIGN_DIR}"' EXIT

# Purgar cruft de Finder / AppleDouble que rompe el sellado de codesign
find "${APP_PATH}" \( -name '.DS_Store' -o -name '._*' \) -print -delete 2>/dev/null || true
command -v dot_clean >/dev/null 2>&1 && dot_clean -m "${APP_PATH}" 2>/dev/null || true

# ── 3. Firma ─────────────────────────────────────────────────────────────────
info "Aplicando firma (${SIGN_MODE})..."
# Firmamos de dentro hacia fuera: dylibs → frameworks → binario principal → .app
# NUNCA usamos `codesign --deep` para FIRMAR (solo sirve para verificar y provoca
# `Bus error: 10` en apps Flutter grandes con Xcode beta). Sellamos cada componente
# explícitamente y luego el bundle sin --deep.

# 3·0. Limpiar extended attributes de TODO el bundle (com.apple.provenance,
#      quarantine, ResourceFork...) — su presencia hace fallar codesign en discos
#      externos y en algunas betas de Xcode.
xattr -cr "${APP_PATH}" 2>/dev/null || true

# 3·0b. Quitar el bit de ejecución a los ficheros de Contents/Resources.
#       Un recurso con +x (típico: `.env` copiado con modo 0700) hace que codesign
#       lo trate como código anidado → "a sealed resource is missing or invalid".
if [ -d "${APP_PATH}/Contents/Resources" ]; then
  find "${APP_PATH}/Contents/Resources" -type f -exec chmod a-x {} + 2>/dev/null || true
fi

# 3a. Firmar dylibs sueltos dentro de Frameworks (Mach-O que NO son bundles)
# Usamos -exec en lugar de | while read para evitar problemas con nombres
# que contienen caracteres especiales (acentos, espacios) en encodings NFD/NFC.
if [ "${SIGN_MODE}" = "developer-id" ]; then
  find "${APP_PATH}/Contents/Frameworks" -type f -name "*.dylib" \
    -exec codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" {} \; 2>&1 || true
else
  find "${APP_PATH}/Contents/Frameworks" -type f -name "*.dylib" \
    -exec codesign --force --sign - {} \; 2>&1 || true
fi

# 3b. Firmar los framework BUNDLES.
# NO firmamos el binario interno por separado: codesign resuelve la estructura
# Versions/Current internamente. Firmarlo a mano a través del symlink
# `X.framework/X` corrompe el sello del bundle y produce, al verificar el .app,
# "a sealed resource is missing or invalid".
if [ "${SIGN_MODE}" = "developer-id" ]; then
  find "${APP_PATH}/Contents/Frameworks" -maxdepth 1 -name "*.framework" \
    -exec codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" {} \; 2>&1 || true
else
  find "${APP_PATH}/Contents/Frameworks" -maxdepth 1 -name "*.framework" \
    -exec codesign --force --sign - {} \; 2>&1 || true
fi

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
  _cs "${BINARY_PATH}" 2>&1 \
    && info "  ✓ Binario firmado" \
    || warning "  No se pudo firmar ${BINARY_NAME} (binario con subcomponentes DartVM — no crítico)"
else
  warning "  Binario no encontrado en: ${BINARY_PATH}"
  info "  Contenido de Contents/MacOS/:"
  ls -la "${APP_PATH}/Contents/MacOS/" 2>&1 || true
fi

# 3d. Firmar el bundle .app completo con entitlements (sandbox). SIN --deep.
ENTITLEMENTS_PATH="$(dirname "$0")/../macos/Runner/Release.entitlements"
_sign_app() {
  local ent_args=()
  [ -f "${ENTITLEMENTS_PATH}" ] && ent_args=(--entitlements "${ENTITLEMENTS_PATH}")
  if [ "${SIGN_MODE}" = "developer-id" ]; then
    codesign --force --options runtime --timestamp \
      "${ent_args[@]}" --sign "${SIGN_IDENTITY}" "${APP_PATH}" 2>&1
  else
    codesign --force --sign - "${ent_args[@]}" "${APP_PATH}" 2>&1
  fi
}
info "  Firmando bundle .app..."
_sign_app || warning "  codesign del bundle devolvió error (revisar arriba)"

# 3e. Verificar la firma.
#     GATE = `codesign --verify` SIN --deep/--strict (Apple recomienda no usar
#     --deep para verificar; en betas de macOS da falsos "a sealed resource is
#     missing or invalid"). El juez real de si el bundle vale es `notarytool`.
info "  Verificando firma (gate: codesign --verify)..."
if codesign --verify --verbose=2 "${APP_PATH}" 2>&1; then
  info "  ✓ codesign --verify OK (gate)"
  # Chequeo profundo SOLO informativo — no bloquea nada.
  if codesign --verify --deep --strict --verbose=2 "${APP_PATH}" >/dev/null 2>&1; then
    info "  ✓ (además) --deep --strict OK"
  else
    warning "  --deep --strict reporta problemas (INFORMATIVO — el juez real es notarytool)"
  fi
else
  warning "  codesign --verify (gate) FALLÓ — diagnóstico:"
  echo "  ── qué recurso está mal (missing/added/modified) ────────────"
  codesign --verify --verbose=4 "${APP_PATH}" 2>&1 \
    | grep -iE 'missing|invalid|modified|added|nested|resource' | sed 's/^/    /' || true
  echo "  ── symlinks dentro del bundle ──────────────────────────────"
  find "${APP_PATH}" -type l | sed 's/^/    /' || true
  echo "  ── entradas de Contents/Frameworks/ ────────────────────────"
  ls -la "${APP_PATH}/Contents/Frameworks/" | sed 's/^/    /' || true
  echo "  ── Base.lproj/ ─────────────────────────────────────────────"
  ls -laR "${APP_PATH}/Contents/Resources/Base.lproj/" 2>&1 | sed 's/^/    /' || true
  echo "  ── codesign -dvvv (firma del bundle) ───────────────────────"
  codesign -dvvv "${APP_PATH}" 2>&1 | sed 's/^/    /' || true
  echo "  ────────────────────────────────────────────────────────────"
  trap - EXIT
  warning "  Bundle firmado conservado en: ${APP_PATH}"
  [ "${SIGN_MODE}" = "developer-id" ] && error "Firma inválida (gate). Abortado antes de notarizar."
  warning "  (modo ad-hoc — se continúa igualmente)"
fi
if [ "${SIGN_MODE}" = "developer-id" ]; then
  # spctl rechazará hasta que el DMG esté notarizado y grapado: es lo esperado aquí.
  spctl -a -vvv -t exec "${APP_PATH}" 2>&1 || \
    info "  (spctl rechaza hasta completar la notarización — normal en este punto)"
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

# ── 6. Firma del DMG + notarización (solo Developer ID) ─────────────────────
if [ "${SIGN_MODE}" = "developer-id" ]; then
  info "Firmando el DMG..."
  codesign --force --timestamp --sign "${SIGN_IDENTITY}" "${FINAL_DMG}" 2>&1 \
    && info "  ✓ DMG firmado" \
    || warning "  No se pudo firmar el DMG"

  if [ "${SKIP_NOTARIZE}" -eq 1 ]; then
    warning "Notarización omitida (--skip-notarize). El DMG está firmado pero Gatekeeper"
    warning "seguirá pidiendo confirmación en otros Macs hasta notarizar + staple."
  else
    # Resolver credenciales de notarytool
    NOTARY_ARGS=()
    if [ -n "${NOTARY_PROFILE:-}" ]; then
      NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE}")
      info "Notarizando con perfil de llavero '${NOTARY_PROFILE}'..."
    elif [ -n "${NOTARY_API_KEY:-}" ] && [ -n "${NOTARY_API_KEY_ID:-}" ] && [ -n "${NOTARY_API_ISSUER:-}" ]; then
      NOTARY_ARGS=(--key "${NOTARY_API_KEY}" --key-id "${NOTARY_API_KEY_ID}" --issuer "${NOTARY_API_ISSUER}")
      info "Notarizando con API Key de App Store Connect..."
    else
      warning "Sin credenciales de notarización. Define NOTARY_PROFILE o"
      warning "NOTARY_API_KEY + NOTARY_API_KEY_ID + NOTARY_API_ISSUER."
      warning "Crear perfil:  xcrun notarytool store-credentials \"edf-notary\" \\"
      warning "                 --apple-id TU_APPLE_ID --team-id \${APPLE_TEAM_ID} --password APP_SPECIFIC_PW"
      warning "Ver docs/macos/DISTRIBUCION_MACOS.md §3"
      NOTARY_ARGS=()
    fi

    if [ "${#NOTARY_ARGS[@]}" -gt 0 ]; then
      set +e
      SUBMIT_OUT="$(xcrun notarytool submit "${FINAL_DMG}" "${NOTARY_ARGS[@]}" --wait 2>&1)"
      SUBMIT_RC=$?
      set -e
      echo "${SUBMIT_OUT}"
      if [ ${SUBMIT_RC} -eq 0 ] && echo "${SUBMIT_OUT}" | grep -q "status: Accepted"; then
        info "  ✓ Notarización aceptada — grapando ticket..."
        xcrun stapler staple "${FINAL_DMG}" 2>&1 && info "  ✓ stapler staple OK"
        xcrun stapler validate "${FINAL_DMG}" 2>&1 && info "  ✓ stapler validate OK"
        spctl -a -vvv -t install "${FINAL_DMG}" 2>&1 || true
      else
        SUB_ID="$(echo "${SUBMIT_OUT}" | awk '/id:/ {print $2; exit}')"
        warning "Notarización NO aceptada. Log detallado:"
        [ -n "${SUB_ID}" ] && xcrun notarytool log "${SUB_ID}" "${NOTARY_ARGS[@]}" 2>&1 || true
        warning "Corrige los problemas (normalmente Hardened Runtime / entitlements) y reintenta."
      fi
    fi
  fi
fi

# ── 7. Resultado ──────────────────────────────────────────────────────────────
echo ""
info "✅ DMG creado:"
ls -lh "${FINAL_DMG}"
echo ""
echo -e "${GREEN}  Ubicación: $(pwd)/${FINAL_DMG}${NC}"
echo ""
echo "Para instalar: abre el DMG → arrastra '${APP_BUNDLE}' a Applications"
echo ""
if [ "${SIGN_MODE}" = "adhoc" ]; then
  warning "Nota: al ser ad-hoc (sin Developer ID), la primera vez que"
  warning "abras la app en otro Mac tendrás que ir a:"
  warning "  Ajustes del Sistema → Privacidad y Seguridad → Abrir de todas formas"
elif [ "${SKIP_NOTARIZE}" -eq 1 ]; then
  warning "DMG firmado con Developer ID pero SIN notarizar: Gatekeeper seguirá avisando."
else
  info "DMG firmado y (si la notarización fue aceptada) grapado: apertura con doble clic."
fi
