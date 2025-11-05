#!/bin/bash

# Script para copiar el archivo .env al bundle de la aplicación Linux
# Este script se ejecuta automáticamente durante el build de CMake

# Obtener la ruta del proyecto
# Si PROJECT_DIR está definido (desde CMake), usarlo, sino calcular desde el script
if [ -n "$PROJECT_DIR" ]; then
    # Ejecutándose desde CMake build
    PROJECT_ROOT="$PROJECT_DIR/.."
else
    # Ejecutándose manualmente - calcular desde la ubicación del script
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

ENV_FILE="$PROJECT_ROOT/.env"

# Determinar la ruta del bundle de Linux
# En Linux, el bundle normalmente está en: build/linux/<arch>/bundle/
if [ -n "$BUILD_BUNDLE_DIR" ]; then
    # Variable de CMake está disponible
    BUNDLE_DIR="$BUILD_BUNDLE_DIR"
    echo "📦 [Build] Copiando .env al bundle de Linux..."
elif [ -n "$CMAKE_INSTALL_PREFIX" ]; then
    # Variable de CMake install está disponible
    BUNDLE_DIR="$CMAKE_INSTALL_PREFIX"
    echo "📦 [Build] Copiando .env al bundle (install prefix)..."
else
    # Ejecutándose manualmente - buscar en ubicaciones comunes
    if [ -d "$PROJECT_ROOT/build/linux/x64/bundle" ]; then
        BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/bundle"
    elif [ -d "$PROJECT_ROOT/build/linux/arm64/bundle" ]; then
        BUNDLE_DIR="$PROJECT_ROOT/build/linux/arm64/bundle"
    else
        # Buscar cualquier directorio bundle
        BUNDLE_DIR=$(find "$PROJECT_ROOT/build/linux" -name "bundle" -type d 2>/dev/null | head -1)
        if [ -z "$BUNDLE_DIR" ]; then
            echo "⚠️ No se encontró directorio bundle, intentando crear..."
            BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/bundle"
        fi
    fi
    echo "📦 [Manual] Copiando .env al bundle..."
fi

# Crear directorio del bundle si no existe
mkdir -p "$BUNDLE_DIR"

# Copiar .env si existe
if [ -f "$ENV_FILE" ]; then
    # Copiar al directorio raíz del bundle
    cp "$ENV_FILE" "$BUNDLE_DIR/.env"
    echo "✅ Archivo .env copiado a $BUNDLE_DIR/.env"
    
    # También copiar al directorio de datos si existe
    if [ -d "$BUNDLE_DIR/data" ]; then
        cp "$ENV_FILE" "$BUNDLE_DIR/data/.env"
        echo "✅ Archivo .env también copiado a $BUNDLE_DIR/data/.env"
    fi
else
    echo "⚠️ Archivo .env no encontrado en $ENV_FILE"
    exit 0  # No fallar el build si no existe .env
fi

