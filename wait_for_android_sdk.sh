#!/bin/bash

# Script para verificar periódicamente si el Android SDK está instalado

SDK_PATH="$HOME/Library/Android/sdk"
CHECK_INTERVAL=30  # Verificar cada 30 segundos
MAX_CHECKS=60      # Máximo 60 intentos (30 minutos)
CHECK_COUNT=0

echo "🔍 Verificando periódicamente la instalación del Android SDK..."
echo "📍 Ruta esperada: $SDK_PATH"
echo "⏱️  Intervalo de verificación: ${CHECK_INTERVAL} segundos"
echo "🛑 Máximo de intentos: ${MAX_CHECKS} (${MAX_CHECKS * CHECK_INTERVAL / 60} minutos)"
echo ""
echo "💡 Presiona Ctrl+C para cancelar"
echo ""

while [ $CHECK_COUNT -lt $MAX_CHECKS ]; do
    CHECK_COUNT=$((CHECK_COUNT + 1))
    
    echo "[Intento $CHECK_COUNT/$MAX_CHECKS] Verificando..."
    
    if [ -d "$SDK_PATH" ]; then
        echo ""
        echo "🎉 ¡SDK encontrado!"
        echo ""
        
        # Verificar componentes importantes
        COMPONENTS_OK=true
        
        if [ -d "$SDK_PATH/platform-tools" ]; then
            echo "✅ platform-tools instalado"
        else
            echo "⚠️  platform-tools no encontrado"
            COMPONENTS_OK=false
        fi
        
        if [ -d "$SDK_PATH/platforms" ] && [ "$(ls -A $SDK_PATH/platforms 2>/dev/null)" ]; then
            echo "✅ platforms instalado"
            echo "   Plataformas disponibles:"
            ls -1 "$SDK_PATH/platforms" 2>/dev/null | sed 's/^/     - /'
        else
            echo "⚠️  platforms aún no disponible (puede estar instalándose)"
            COMPONENTS_OK=false
        fi
        
        if [ -d "$SDK_PATH/build-tools" ] && [ "$(ls -A $SDK_PATH/build-tools 2>/dev/null)" ]; then
            echo "✅ build-tools instalado"
            echo "   Versiones disponibles:"
            ls -1 "$SDK_PATH/build-tools" 2>/dev/null | sed 's/^/     - /'
        else
            echo "⚠️  build-tools aún no disponible (puede estar instalándose)"
            COMPONENTS_OK=false
        fi
        
        if [ "$COMPONENTS_OK" = true ]; then
            echo ""
            echo "✅ ¡SDK completamente instalado y listo!"
            echo ""
            echo "📋 Verificando con Flutter..."
            flutter doctor -v | grep -A 10 "Android toolchain" || echo ""
            
            echo ""
            echo "🎯 Próximos pasos:"
            echo "   1. Ejecuta: flutter doctor"
            echo "   2. Si hay licencias pendientes: flutter doctor --android-licenses"
            echo "   3. Intenta compilar tu proyecto Android"
            echo ""
            
            # Notificación visual (solo en macOS)
            if command -v osascript &> /dev/null; then
                osascript -e 'display notification "Android SDK está instalado y listo" with title "SDK Instalado" sound name "Glass"'
            fi
            
            exit 0
        else
            echo ""
            echo "⏳ SDK encontrado pero aún se están instalando componentes..."
            echo "   Esperando ${CHECK_INTERVAL} segundos más..."
        fi
    else
        echo "⏳ SDK aún no instalado... (esperando ${CHECK_INTERVAL} segundos)"
    fi
    
    sleep $CHECK_INTERVAL
done

echo ""
echo "⏰ Tiempo máximo alcanzado sin detectar el SDK"
echo ""
echo "💡 Verifica manualmente:"
echo "   1. ¿Completaste el asistente de Android Studio?"
echo "   2. ¿Se instaló correctamente el SDK?"
echo "   3. Ejecuta: bash check_android_sdk.sh"
echo ""
exit 1

