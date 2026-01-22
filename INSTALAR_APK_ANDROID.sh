#!/bin/bash

# Script para instalar el APK en un emulador/dispositivo Android
# Este script espera a que un dispositivo esté disponible y luego instala el APK

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-debug.apk"

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Instalando APK en dispositivo Android...${NC}"
echo ""

# Verificar que el APK existe
if [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}❌ Error: No se encontró el APK en $APK_PATH${NC}"
    echo "   Por favor, compila primero la aplicación:"
    echo "   ./build_android.sh"
    exit 1
fi

echo -e "${GREEN}✅ APK encontrado: $APK_PATH${NC}"
echo ""

# Verificar que adb está disponible
if ! command -v adb &> /dev/null; then
    echo -e "${YELLOW}⚠️  adb no está en el PATH, intentando usar ANDROID_HOME...${NC}"
    if [ -z "$ANDROID_HOME" ]; then
        echo -e "${RED}❌ Error: ANDROID_HOME no está configurado${NC}"
        exit 1
    fi
    export PATH="$ANDROID_HOME/platform-tools:$PATH"
fi

# Esperar a que un dispositivo esté disponible
echo -e "${YELLOW}⏳ Esperando a que un dispositivo Android esté disponible...${NC}"
MAX_WAIT=120  # Esperar máximo 2 minutos
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l | tr -d ' ')
    
    if [ "$DEVICES" -gt 0 ]; then
        echo -e "${GREEN}✅ Dispositivo encontrado!${NC}"
        break
    fi
    
    echo -e "${YELLOW}   Esperando... (${WAITED}s/${MAX_WAIT}s)${NC}"
    sleep 5
    WAITED=$((WAITED + 5))
done

# Verificar si hay dispositivos disponibles
DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l | tr -d ' ')

if [ "$DEVICES" -eq 0 ]; then
    echo -e "${RED}❌ Error: No se encontró ningún dispositivo Android${NC}"
    echo ""
    echo "Opciones:"
    echo "1. Inicia un emulador desde Android Studio"
    echo "2. Conecta un dispositivo físico y habilita la depuración USB"
    echo "3. Ejecuta: flutter emulators --launch <emulator_id>"
    exit 1
fi

# Mostrar dispositivos disponibles
echo ""
echo -e "${GREEN}📱 Dispositivos disponibles:${NC}"
adb devices
echo ""

# Instalar el APK
echo -e "${GREEN}📦 Instalando APK...${NC}"
if adb install -r "$APK_PATH"; then
    echo ""
    echo -e "${GREEN}✅ APK instalado exitosamente!${NC}"
    echo ""
    echo "Para ejecutar la aplicación, puedes:"
    echo "1. Buscar la aplicación en el dispositivo/emulador"
    echo "2. Ejecutar: adb shell am start -n com.example.edfcatalogo_multiplatform/.MainActivity"
    echo "3. O ejecutar desde Flutter: flutter run -d android"
else
    echo ""
    echo -e "${RED}❌ Error al instalar el APK${NC}"
    echo "Revisa los logs anteriores para más detalles."
    exit 1
fi

