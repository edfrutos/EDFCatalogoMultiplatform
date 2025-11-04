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

# Determinar la ruta del bundle
if [ -n "$BUILT_PRODUCTS_DIR" ] && [ -n "$CONTENTS_FOLDER_PATH" ]; then
    # Variables de Xcode están disponibles
    RESOURCES_DIR="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources"
    echo "📦 [Build] Copiando .env al bundle..."
elif [ -n "$PROJECT_DIR" ]; then
    # Estamos en build pero variables específicas no están, usar path relativo
    RESOURCES_DIR="$PROJECT_DIR/../build/macos/Build/Products/$CONFIGURATION/edfcatalogomultiplatform.app/Contents/Resources"
    echo "📦 [Build] Copiando .env al bundle (path alternativo)..."
else
    # Ejecutándose manualmente - usar rutas por defecto
    BUILD_DIR="$PROJECT_ROOT/build/macos/Build/Products"
    RESOURCES_DIR="$BUILD_DIR/Debug/edfcatalogomultiplatform.app/Contents/Resources"
    echo "📦 [Manual] Copiando .env al bundle..."
fi

# Crear directorio Resources si no existe
mkdir -p "$RESOURCES_DIR"

# Copiar .env si existe
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$RESOURCES_DIR/.env"
    echo "✅ Archivo .env copiado a $RESOURCES_DIR/.env"
    
    # También copiar para Release si estamos en Debug (para facilitar)
    if [ "$CONFIGURATION" = "Debug" ] && [ -d "$(dirname "$RESOURCES_DIR")/../../../Release" ]; then
        RELEASE_RESOURCES_DIR="$(dirname "$RESOURCES_DIR")/../../../Release/edfcatalogomultiplatform.app/Contents/Resources"
        mkdir -p "$RELEASE_RESOURCES_DIR"
        cp "$ENV_FILE" "$RELEASE_RESOURCES_DIR/.env"
        echo "✅ Archivo .env también copiado para Release"
    fi
else
    echo "⚠️ Archivo .env no encontrado en $ENV_FILE"
    exit 0  # No fallar el build si no existe .env
fi

