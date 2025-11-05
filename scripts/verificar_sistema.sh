#!/bin/bash

# Script para verificar el sistema y Docker

echo "🔍 Verificando sistema..."
echo ""

# Verificar sistema operativo
echo "📊 Sistema Operativo:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   ✅ macOS detectado"
    sw_vers
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "   ✅ Linux detectado"
    uname -a
    lsb_release -a 2>/dev/null || cat /etc/os-release
else
    echo "   ⚠️ Sistema desconocido: $OSTYPE"
fi
echo ""

# Verificar Docker
echo "🐳 Docker:"
if command -v docker &> /dev/null; then
    echo "   ✅ Docker está instalado"
    docker --version
    
    # Verificar si Docker está corriendo
    if docker info &> /dev/null; then
        echo "   ✅ Docker está corriendo"
        echo "   📊 Contenedores activos: $(docker ps -q | wc -l | tr -d ' ')"
    else
        echo "   ⚠️ Docker está instalado pero NO está corriendo"
        echo "   💡 Inicia Docker Desktop o el servicio Docker"
    fi
else
    echo "   ❌ Docker NO está instalado"
    echo "   💡 Instala Docker Desktop desde: https://www.docker.com/products/docker-desktop"
fi
echo ""

# Verificar Docker Compose
echo "🐳 Docker Compose:"
if command -v docker-compose &> /dev/null; then
    echo "   ✅ Docker Compose está instalado (v1)"
    docker-compose --version
elif docker compose version &> /dev/null 2>&1; then
    echo "   ✅ Docker Compose está instalado (v2)"
    docker compose version
else
    echo "   ⚠️ Docker Compose no encontrado"
    echo "   💡 Se instalará automáticamente con Docker Desktop"
fi
echo ""

# Verificar Flutter
echo "📱 Flutter:"
if command -v flutter &> /dev/null; then
    echo "   ✅ Flutter está instalado"
    flutter --version | head -1
    echo ""
    echo "   📊 Soporte Linux:"
    if flutter config | grep -q "enable-linux-desktop.*true"; then
        echo "   ✅ Linux desktop está habilitado"
    else
        echo "   ⚠️ Linux desktop NO está habilitado"
        echo "   💡 Ejecuta: flutter config --enable-linux-desktop"
    fi
else
    echo "   ❌ Flutter NO está instalado"
fi
echo ""

# Resumen
echo "📋 Resumen:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   ✅ Estás en macOS"
    echo "   💡 Puedes usar Docker para probar Linux sin necesidad de instalar Linux"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "   ✅ Ya estás en Linux!"
    echo "   💡 Puedes compilar directamente: flutter build linux --debug"
else
    echo "   ⚠️ Sistema desconocido"
fi

if command -v docker &> /dev/null && docker info &> /dev/null; then
    echo "   ✅ Docker está listo para usar"
    echo "   💡 Puedes usar: docker-compose -f docker/docker-compose.linux-test.yml build"
else
    echo "   ⚠️ Docker no está disponible"
fi

echo ""
echo "📚 Para más información, consulta: PROBAR_LINUX_CON_DOCKER.md"

