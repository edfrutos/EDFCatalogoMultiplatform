#!/bin/bash

# Script para verificar si el Android SDK está instalado

SDK_PATH="$HOME/Library/Android/sdk"

echo "🔍 Verificando instalación del Android SDK..."
echo ""

if [ -d "$SDK_PATH" ]; then
    echo "✅ SDK encontrado en: $SDK_PATH"
    echo ""
    
    # Verificar componentes importantes
    if [ -d "$SDK_PATH/platform-tools" ]; then
        echo "✅ platform-tools instalado"
    else
        echo "⚠️  platform-tools no encontrado"
    fi
    
    if [ -d "$SDK_PATH/platforms" ]; then
        echo "✅ platforms instalado"
        echo "   Plataformas disponibles:"
        ls -1 "$SDK_PATH/platforms" 2>/dev/null | sed 's/^/     - /'
    else
        echo "⚠️  platforms no encontrado"
    fi
    
    if [ -d "$SDK_PATH/build-tools" ]; then
        echo "✅ build-tools instalado"
        echo "   Versiones disponibles:"
        ls -1 "$SDK_PATH/build-tools" 2>/dev/null | sed 's/^/     - /'
    else
        echo "⚠️  build-tools no encontrado"
    fi
    
    echo ""
    echo "📋 Verificando con Flutter..."
    flutter doctor -v | grep -A 5 "Android toolchain" || echo "   Ejecuta 'flutter doctor' para más detalles"
    
else
    echo "⏳ SDK aún no instalado en: $SDK_PATH"
    echo ""
    echo "📝 Instrucciones:"
    echo "   1. Abre Android Studio"
    echo "   2. Completa el asistente de configuración inicial"
    echo "   3. Selecciona 'Standard' installation"
    echo "   4. Espera a que se instale el SDK"
    echo ""
    echo "   Una vez instalado, ejecuta este script nuevamente para verificar."
fi

