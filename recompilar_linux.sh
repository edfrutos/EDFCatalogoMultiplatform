#!/bin/bash

# Script para recompilar la aplicación Flutter para Linux
# Uso: ./recompilar_linux.sh

set -e  # Salir si hay algún error

echo "🔨 Iniciando recompilación para Linux..."
echo ""

# Cambiar al directorio del proyecto
cd "$(dirname "$0")"

# Limpiar builds anteriores
echo "🧹 Limpiando builds anteriores..."
flutter clean

# Recompilar para Linux en modo release
echo ""
echo "🔨 Compilando para Linux (release)..."
flutter build linux --release

# Verificar que el bundle existe
BUNDLE_DIR="build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ Error: No se encontró el directorio del bundle: $BUNDLE_DIR"
    exit 1
fi

# Copiar el archivo .env al bundle
echo ""
echo "📋 Copiando archivo .env al bundle..."
if [ -f ".env" ]; then
    cp .env "$BUNDLE_DIR/.env"
    cp .env "$BUNDLE_DIR/data/.env"
    echo "✅ Archivo .env copiado correctamente"
else
    echo "⚠️  Advertencia: No se encontró el archivo .env en el directorio raíz"
fi

# Verificar el ejecutable
EXECUTABLE="$BUNDLE_DIR/edfcatalogomultiplatform"
if [ -f "$EXECUTABLE" ]; then
    echo ""
    echo "✅ Compilación completada exitosamente!"
    echo ""
    echo "📦 Ubicación del ejecutable:"
    echo "   $EXECUTABLE"
    echo ""
    echo "🚀 Para ejecutar la aplicación:"
    echo "   $EXECUTABLE"
    echo ""
    # Mostrar información del ejecutable
    file "$EXECUTABLE"
    ls -lh "$EXECUTABLE"
else
    echo "❌ Error: No se encontró el ejecutable en: $EXECUTABLE"
    exit 1
fi

