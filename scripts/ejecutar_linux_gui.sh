#!/bin/bash

# Script para ejecutar la aplicación Linux con GUI en Docker
# Requiere: XQuartz instalado y reiniciado

set -e

echo "🚀 Ejecutando aplicación Linux con GUI..."

# Verificar que XQuartz esté funcionando
XHOST_CMD=$(command -v xhost 2>/dev/null || echo "/opt/X11/bin/xhost")
if [[ ! -x "$XHOST_CMD" ]]; then
    echo "❌ Error: XQuartz no está disponible. Por favor:"
    echo "   1. Instala XQuartz: brew install --cask xquartz"
    echo "   2. Cierra sesión o reinicia tu Mac"
    echo "   3. Vuelve a ejecutar este script"
    exit 1
fi

# Configurar permisos X11
echo "📋 Configurando permisos X11..."
export DISPLAY=:0

# Verificar que XQuartz esté corriendo
if [[ ! -S /tmp/.X11-unix/X0 ]]; then
    echo "⚠️  Socket X11 no encontrado. Iniciando XQuartz..."
    open -a XQuartz
    sleep 5
    # Verificar nuevamente
    if [[ ! -S /tmp/.X11-unix/X0 ]]; then
        echo "❌ Error: No se pudo iniciar XQuartz. Por favor inícialo manualmente."
        exit 1
    fi
fi
echo "✅ XQuartz está corriendo"

# Configurar permisos X11 (permitir todas las conexiones)
echo "🔧 Configurando permisos X11..."
export DISPLAY=:0
"$XHOST_CMD" + 2>/dev/null || echo "⚠️  No se pudieron configurar permisos X11"

# En macOS, usar socat para crear un túnel TCP (XQuartz no escucha en TCP por defecto)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Verificar si socat está instalado
    if ! command -v socat &> /dev/null; then
        echo "❌ Error: socat no está instalado. Instálalo con: brew install socat"
        exit 1
    fi
    
    # Obtener IP del host
    HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
    X11_PORT=6000
    
    # Verificar si ya hay un túnel corriendo
    if lsof -i :$X11_PORT >/dev/null 2>&1; then
        echo "⚠️  Puerto $X11_PORT ya está en uso, reutilizando..."
    else
        echo "🔌 Creando túnel TCP con socat (puerto $X11_PORT)..."
        # Crear túnel TCP que redirige al socket Unix
        socat TCP-LISTEN:$X11_PORT,bind=$HOST_IP,reuseaddr,fork UNIX-CONNECT:/tmp/.X11-unix/X0 &
        SOCAT_PID=$!
        sleep 2
        
        # Verificar que socat esté corriendo
        if ! kill -0 $SOCAT_PID 2>/dev/null; then
            echo "❌ Error: No se pudo iniciar el túnel socat"
            exit 1
        fi
        
        echo "✅ Túnel TCP creado (PID: $SOCAT_PID)"
        
        # Función de limpieza
        cleanup() {
            echo "🧹 Limpiando túnel socat..."
            kill $SOCAT_PID 2>/dev/null || true
        }
        trap cleanup EXIT
    fi
    
    DOCKER_DISPLAY="$HOST_IP:0"
    echo "🖥️  IP del host: $HOST_IP"
    echo "🖥️  DISPLAY para Docker: $DOCKER_DISPLAY (TCP vía socat)"
else
    # Linux - usar socket Unix directamente
    DOCKER_DISPLAY=":0"
    echo "🖥️  DISPLAY para Docker: $DOCKER_DISPLAY (Unix socket)"
fi

# Cambiar al directorio del proyecto
cd "$(dirname "$0")/.."

# Ejecutar la aplicación
echo "🐳 Ejecutando en Docker..."
echo "🔧 Variables de entorno para software rendering:"
echo "   - LIBGL_ALWAYS_SOFTWARE=1"
echo "   - GALLIUM_DRIVER=llvmpipe"
echo "   - MESA_GL_VERSION_OVERRIDE=3.3"
echo "   - LIBGL_ALWAYS_INDIRECT=1"

docker-compose -f docker/docker-compose.linux-test.yml run --rm \
    -e DISPLAY="$DOCKER_DISPLAY" \
    -e LIBGL_ALWAYS_SOFTWARE=1 \
    -e GALLIUM_DRIVER=llvmpipe \
    -e MESA_GL_VERSION_OVERRIDE=3.3 \
    -e LIBGL_ALWAYS_INDIRECT=0 \
    -e __GLX_VENDOR_LIBRARY_NAME=mesa \
    -e GDK_BACKEND=x11 \
    -e GDK_GL=gles \
    -e QT_X11_NO_MITSHM=1 \
    -e MESA_LOADER_DRIVER_OVERRIDE=llvmpipe \
    flutter-linux-test bash -c "
        cd /app && 
        flutter pub get && 
        export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe GDK_BACKEND=x11 GDK_GL=gles && 
        echo '🔍 Verificando configuración OpenGL...' && 
        echo '   LIBGL_ALWAYS_SOFTWARE='\$LIBGL_ALWAYS_SOFTWARE && 
        echo '   GALLIUM_DRIVER='\$GALLIUM_DRIVER && 
        echo '   GDK_GL='\$GDK_GL && 
        echo '🚀 Ejecutando en modo release...' && 
        flutter run --release -d linux 2>&1 | head -100
    "

echo "✅ Aplicación ejecutada"

