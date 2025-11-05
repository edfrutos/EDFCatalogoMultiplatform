#!/bin/bash

# Script para copiar el archivo .env al bundle de la aplicación iOS
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

# Determinar la ruta del bundle de iOS
if [ -n "$BUILT_PRODUCTS_DIR" ] && [ -n "$CONTENTS_FOLDER_PATH" ]; then
    # Variables de Xcode están disponibles
    # Para iOS, el bundle es diferente: el .app está directamente en BUILT_PRODUCTS_DIR
    APP_BUNDLE="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"
    RESOURCES_DIR="$APP_BUNDLE"
    echo "📦 [Build] Copiando .env al bundle de iOS..."
elif [ -n "$PROJECT_DIR" ]; then
    # Estamos en build pero variables específicas no están, usar path relativo
    # Para iOS, el bundle está en build/ios/iphoneos o build/ios/iphonesimulator
    RESOURCES_DIR="$PROJECT_DIR/../build/ios/${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}/$PRODUCT_NAME.app"
    echo "📦 [Build] Copiando .env al bundle (path alternativo)..."
else
    # Ejecutándose manualmente - usar rutas por defecto
    # Intentar detectar si es simulador o dispositivo
    if [ -d "$PROJECT_ROOT/build/ios/iphonesimulator" ]; then
        BUILD_DIR="$PROJECT_ROOT/build/ios/iphonesimulator"
    else
        BUILD_DIR="$PROJECT_ROOT/build/ios/iphoneos"
    fi
    RESOURCES_DIR="$BUILD_DIR/Debug-iphonesimulator/Runner.app"
    echo "📦 [Manual] Copiando .env al bundle..."
fi

# Crear directorio del bundle si no existe
mkdir -p "$RESOURCES_DIR"

# Copiar .env si existe
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$RESOURCES_DIR/.env"
    echo "✅ Archivo .env copiado a $RESOURCES_DIR/.env"
    
    # También copiar para Release si estamos en Debug (para facilitar)
    if [ "$CONFIGURATION" = "Debug" ] && [ -n "$PROJECT_DIR" ]; then
        RELEASE_DIR="$PROJECT_DIR/../build/ios/${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}/../Release${EFFECTIVE_PLATFORM_NAME}/$PRODUCT_NAME.app"
        if [ -d "$(dirname "$RELEASE_DIR")" ]; then
            mkdir -p "$RELEASE_DIR"
            cp "$ENV_FILE" "$RELEASE_DIR/.env"
            echo "✅ Archivo .env también copiado para Release"
        fi
    fi
else
    echo "⚠️ Archivo .env no encontrado en $ENV_FILE"
    exit 0  # No fallar el build si no existe .env
fi

