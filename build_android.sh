#!/bin/bash

# Script para compilar la aplicación Android con todas las verificaciones necesarias

set -e  # Salir si hay algún error

echo "🚀 Iniciando compilación de Android..."
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_step() {
    echo -e "${GREEN}▶ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Paso 1: Verificar Java
print_step "Verificando Java..."
if ! command -v java &> /dev/null; then
    print_error "Java no está instalado"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -1 | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt 17 ]; then
    print_error "Java 17 o superior es requerido. Versión actual: $JAVA_VERSION"
    exit 1
fi
echo "   ✅ Java $JAVA_VERSION encontrado"

# Paso 2: Verificar Flutter
print_step "Verificando Flutter..."
if ! command -v flutter &> /dev/null; then
    print_error "Flutter no está instalado"
    exit 1
fi
echo "   ✅ Flutter encontrado"

# Paso 3: Limpiar proyecto
print_step "Limpiando proyecto..."
flutter clean
echo "   ✅ Proyecto limpiado"

# Paso 4: Obtener dependencias
print_step "Obteniendo dependencias..."
flutter pub get
echo "   ✅ Dependencias obtenidas"

# Paso 5: Sincronizar versiones de Gradle
print_step "Sincronizando versiones de Gradle en plugins..."
if [ -f "./android/sync_gradle_version.sh" ]; then
    bash ./android/sync_gradle_version.sh
    echo "   ✅ Versiones sincronizadas"
else
    print_warning "Script de sincronización no encontrado, continuando..."
fi

# Paso 6: Limpiar caché de Gradle
print_step "Limpiando caché de Gradle..."
cd android
rm -rf .gradle build
cd ..
echo "   ✅ Caché limpiada"

# Paso 7: Verificar configuración de Gradle
print_step "Verificando configuración de Gradle..."
GRADLE_VERSION=$(grep "distributionUrl" android/gradle/wrapper/gradle-wrapper.properties | sed 's/.*gradle-\([0-9.]*\)-.*/\1/')
echo "   ✅ Gradle $GRADLE_VERSION configurado"

AGP_VERSION=$(grep "com.android.application" android/settings.gradle.kts | sed 's/.*version "\([0-9.]*\)".*/\1/')
echo "   ✅ Android Gradle Plugin $AGP_VERSION configurado"

# Paso 8: Compilar APK
print_step "Compilando APK..."
if flutter build apk --debug; then
    echo ""
    echo -e "${GREEN}✅ Compilación exitosa!${NC}"
    echo ""
    echo "APK generado en: build/app/outputs/flutter-apk/app-debug.apk"
    exit 0
else
    echo ""
    print_error "La compilación falló"
    echo ""
    echo "Revisa los logs anteriores para más detalles."
    exit 1
fi

