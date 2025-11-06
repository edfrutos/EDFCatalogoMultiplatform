#!/bin/bash

# Script para ejecutar Flutter en Linux usando Docker
# Uso: ./scripts/flutter_run_linux.sh [opciones de flutter run]
# Ejemplo: ./scripts/flutter_run_linux.sh --release
#          ./scripts/flutter_run_linux.sh --debug

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🐧 Ejecutando Flutter en Linux (Docker)..."
echo "📁 Directorio del proyecto: $PROJECT_DIR"

# Cambiar al directorio del proyecto
cd "$PROJECT_DIR"

# Verificar que Docker está corriendo
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Error: Docker no está corriendo. Por favor inicia Docker Desktop."
    exit 1
fi

# Obtener argumentos adicionales de flutter run
FLUTTER_ARGS="$@"

# Si no se especifican argumentos, usar --debug por defecto
if [ -z "$FLUTTER_ARGS" ]; then
    FLUTTER_ARGS="--debug"
fi

echo "🚀 Iniciando contenedor con Xvfb y VNC..."
echo ""
echo "📋 Instrucciones:"
echo "   1. El contenedor iniciará Xvfb (servidor X virtual)"
echo "   2. x11vnc estará disponible en el puerto 5900"
echo "   3. Conéctate con un cliente VNC a: localhost:5900"
echo "   4. La aplicación Flutter se ejecutará automáticamente"
echo ""
echo "💡 Clientes VNC recomendados para macOS:"
echo "   - RealVNC Viewer: https://www.realvnc.com/download/viewer/"
echo "   - TigerVNC: brew install --cask tigervnc-viewer"
echo "   - Screen Sharing (macOS): Cmd+K, luego vnc://localhost:5900"
echo ""

# Función para limpiar contenedores y puertos
cleanup_containers() {
    echo "🧹 Limpiando contenedores y puertos anteriores..."
    
    # Detener todos los contenedores relacionados con flutter-linux-test
    RUNNING_CONTAINERS=$(docker ps --filter "name=flutter-linux-test" --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        echo "   Deteniendo contenedores de flutter-linux-test..."
        echo "$RUNNING_CONTAINERS" | xargs docker stop 2>/dev/null || true
    fi
    
    # Detener cualquier contenedor que esté usando el puerto 5900
    CONTAINERS_USING_PORT=$(docker ps --filter "publish=5900" --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$CONTAINERS_USING_PORT" ]; then
        echo "   Deteniendo contenedores que usan el puerto 5900..."
        echo "$CONTAINERS_USING_PORT" | xargs docker stop 2>/dev/null || true
    fi
    
    # Detener y eliminar contenedores relacionados con docker-compose
    docker-compose -f docker/docker-compose.linux-test.yml down 2>/dev/null || true
    
    # Eliminar contenedores detenidos
    STOPPED_CONTAINERS=$(docker ps -a --filter "name=flutter-linux-test" --format "{{.ID}}" 2>/dev/null || true)
    if [ -n "$STOPPED_CONTAINERS" ]; then
        echo "   Eliminando contenedores detenidos..."
        echo "$STOPPED_CONTAINERS" | xargs docker rm 2>/dev/null || true
    fi
    
    # Matar procesos locales que usen el puerto 5900 (si no son de Docker)
    if command -v lsof >/dev/null 2>&1; then
        PIDS_USING_PORT=$(lsof -ti :5900 2>/dev/null || true)
        if [ -n "$PIDS_USING_PORT" ]; then
            echo "   Deteniendo procesos locales que usan el puerto 5900..."
            echo "$PIDS_USING_PORT" | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # Esperar a que el puerto se libere
    echo "   Esperando a que el puerto 5900 se libere..."
    for i in {1..10}; do
        PORT_IN_USE=false
        if lsof -i :5900 >/dev/null 2>&1; then
            PORT_IN_USE=true
        fi
        if docker ps --filter "publish=5900" --format "{{.ID}}" 2>/dev/null | grep -q .; then
            PORT_IN_USE=true
        fi
        if [ "$PORT_IN_USE" = false ]; then
            echo "   ✅ Puerto 5900 liberado"
            return 0
        fi
        sleep 1
    done
    
    echo "   ⚠️  El puerto 5900 aún está en uso después de 10 segundos"
    echo "   Puedes intentar detener manualmente con:"
    echo "      docker-compose -f docker/docker-compose.linux-test.yml down"
    echo "      docker ps --filter 'publish=5900' --format '{{.ID}}' | xargs docker stop"
    return 1
}

# Verificar si el puerto 5900 está en uso
if lsof -i :5900 >/dev/null 2>&1 || docker ps --filter "publish=5900" --format "{{.ID}}" | grep -q .; then
    echo "⚠️  El puerto 5900 ya está en uso."
    cleanup_containers
    sleep 1
fi

# Ejecutar el contenedor con Xvfb, x11vnc y Flutter
# Usamos 'run' con --service-ports para asegurar que los puertos se expongan
docker-compose -f docker/docker-compose.linux-test.yml run --rm --service-ports \
    -e DISPLAY=:99 \
    -e LIBGL_ALWAYS_SOFTWARE=1 \
    -e GALLIUM_DRIVER=llvmpipe \
    -e MESA_GL_VERSION_OVERRIDE=3.3 \
    flutter-linux-test bash -c "
        echo '🖥️  Iniciando Xvfb en display :99...'
        Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
        XVFB_PID=\$!
        
        echo '📡 Iniciando x11vnc en puerto 5900...'
        # x11vnc escuchando en todas las interfaces (0.0.0.0) para permitir conexiones desde el host
        x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared -rfbport 5900 -bg -o /tmp/x11vnc.log 2>&1
        VNC_PID=\$(pgrep -f 'x11vnc.*5900' | head -1)
        
        echo '🪟 Iniciando fluxbox (window manager)...'
        DISPLAY=:99 fluxbox > /dev/null 2>&1 &
        FLUXBOX_PID=\$!
        
        echo '⏳ Esperando a que los servicios estén listos...'
        sleep 3
        
        # Verificar que x11vnc está escuchando
        if ! netstat -tuln 2>/dev/null | grep -q ':5900' && ! ss -tuln 2>/dev/null | grep -q ':5900'; then
            echo '⚠️  x11vnc no está escuchando en el puerto 5900. Revisando logs...'
            cat /tmp/x11vnc.log 2>/dev/null || echo 'No se encontraron logs de x11vnc'
            echo '🔄 Reintentando iniciar x11vnc...'
            x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared -rfbport 5900 -bg -o /tmp/x11vnc.log 2>&1
            sleep 2
        fi
        
        # Verificar nuevamente
        if netstat -tuln 2>/dev/null | grep -q ':5900' || ss -tuln 2>/dev/null | grep -q ':5900'; then
            echo '✅ x11vnc está escuchando en el puerto 5900'
        else
            echo '⚠️  Advertencia: No se pudo verificar que x11vnc esté escuchando'
        fi
        
        echo '✅ Servicios iniciados:'
        echo '   - Xvfb (PID: '\$XVFB_PID')'
        echo '   - x11vnc (PID: '\$VNC_PID')'
        echo '   - fluxbox (PID: '\$FLUXBOX_PID')'
        echo ''
        echo '📦 Instalando dependencias de Flutter...'
        cd /app && flutter pub get > /dev/null 2>&1
        
        echo '🎯 Ejecutando Flutter con argumentos: $FLUTTER_ARGS'
        echo ''
        
        # Ejecutar flutter run
        DISPLAY=:99 flutter run -d linux $FLUTTER_ARGS
        
        # Limpiar procesos al salir
        kill \$XVFB_PID \$VNC_PID \$FLUXBOX_PID 2>/dev/null || true
    "

echo "✅ Completado"

