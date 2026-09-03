#!/bin/bash

# Script para copiar el archivo .env al bundle de la aplicación macOS
# Este script se ejecuta automáticamente durante el build de Xcode

# Obtener la ruta del proyecto
# Si PROJECT_DIR está definido (desde Xcode), usarlo, sino calcular desde el script
if [ -n "$PROJECT_DIR" ]; then
    # Ejecutándose desde Xcode build
    PROJECT_ROOT="$PROJECT_DIR/.."
else
    # Ejecutándose manualmente - calcular desde la ubicación del script
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

ENV_FILE="$PROJECT_ROOT/.env"

# Determinar la ruta del bundle.
# El .app se llama "EDFCatalogo.app" (ASCII; el nombre visible con tilde va en
# CFBundleDisplayName). NO hardcodeamos el nombre: variables de Xcode o glob *.app.
if [ -n "$BUILT_PRODUCTS_DIR" ] && [ -n "$CONTENTS_FOLDER_PATH" ]; then
    # Variables de Xcode disponibles (caso normal en `flutter build macos`)
    RESOURCES_DIR="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources"
    echo "📦 [Build] Copiando .env al bundle..."
else
    # Fallback: localizar el primer .app en Products/<Config>/
    CONF="${CONFIGURATION:-Release}"
    PRODUCTS_DIR="${PROJECT_DIR:+$PROJECT_DIR/..}"
    PRODUCTS_DIR="${PRODUCTS_DIR:-$PROJECT_ROOT}/build/macos/Build/Products/$CONF"
    APP_DIR="$(/bin/ls -d "$PRODUCTS_DIR"/*.app 2>/dev/null | head -1)"
    RESOURCES_DIR="${APP_DIR:-$PRODUCTS_DIR/EDFCatalogo.app}/Contents/Resources"
    echo "📦 [Fallback] Copiando .env al bundle en: $RESOURCES_DIR"
fi

# Crear directorio Resources si no existe
mkdir -p "$RESOURCES_DIR"

# Copia el .env con permisos 0644 y SIN bit de ejecución ni xattrs.
# CRÍTICO: un fichero con +x dentro de Contents/Resources/ hace que codesign lo
# trate como "código anidado" y luego `--verify` falle con
# "a sealed resource is missing or invalid". El .env del repo suele ser 0700.
copy_env_clean() {
    local dest="$1/.env"
    /bin/cp "$ENV_FILE" "$dest"
    /bin/chmod 0644 "$dest"
    /usr/bin/xattr -c "$dest" 2>/dev/null || true
    echo "✅ .env copiado (0644, sin xattrs) → $dest"
}

# Copiar .env si existe
if [ -f "$ENV_FILE" ]; then
    copy_env_clean "$RESOURCES_DIR"

    # Si estamos en Debug, replicar también en el .app de Release (si existe)
    if [ "$CONFIGURATION" = "Debug" ]; then
        REL_DIR="$(dirname "$(dirname "$(dirname "$RESOURCES_DIR")")")/../Release"
        REL_APP="$(/bin/ls -d "$REL_DIR"/*.app 2>/dev/null | head -1)"
        if [ -n "$REL_APP" ]; then
            mkdir -p "$REL_APP/Contents/Resources"
            copy_env_clean "$REL_APP/Contents/Resources"
        fi
    fi
else
    echo "⚠️ Archivo .env no encontrado en $ENV_FILE"
    exit 0  # No fallar el build si no existe .env
fi

