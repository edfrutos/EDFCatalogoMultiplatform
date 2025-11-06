#!/bin/bash

# Script para ejecutar la aplicación Linux con GUI usando Xvfb + VNC
# Esta solución funciona completamente dentro de Docker sin necesidad de X11 forwarding

set -e

echo "🚀 Ejecutando aplicación Linux con GUI vía VNC..."

# Cambiar al directorio del proyecto
cd "$(dirname "$0")/.."

# Verificar que Docker está corriendo
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Error: Docker no está corriendo. Por favor inicia Docker Desktop."
    exit 1
fi

# Reconstruir la imagen si es necesario (comentado para ahorrar tiempo)
# echo "🔨 Reconstruyendo imagen Docker..."
# docker-compose -f docker/docker-compose.linux-test.yml build

echo "🐳 Iniciando contenedor con Xvfb y VNC..."
echo ""
echo "📋 Instrucciones:"
echo "   1. El contenedor iniciará Xvfb (servidor X virtual)"
echo "   2. x11vnc estará disponible en el puerto 5900"
echo "   3. Conéctate con un cliente VNC a: localhost:5900"
echo "   4. La aplicación Flutter se ejecutará automáticamente"
echo ""
echo "💡 Clientes VNC recomendados para macOS:"
echo "   - RealVNC Viewer (gratis): https://www.realvnc.com/download/viewer/"
echo "   - TigerVNC (gratis): brew install --cask tigervnc-viewer"
echo "   - Screen Sharing (incluido en macOS): Cmd+K, luego vnc://localhost:5900"
echo ""

# Verificar si el puerto 5900 está en uso
if lsof -i :5900 >/dev/null 2>&1; then
    echo "⚠️  El puerto 5900 ya está en uso. Deteniendo contenedores anteriores..."
    docker-compose -f docker/docker-compose.linux-test.yml down 2>/dev/null || true
    sleep 2
fi

# Ejecutar el contenedor con Xvfb, x11vnc y Flutter
# Usamos 'run' con --service-ports para asegurar que los puertos se expongan
docker-compose -f docker/docker-compose.linux-test.yml run --rm --service-ports \
    -e DISPLAY=:99 \
    -e LIBGL_ALWAYS_SOFTWARE=1 \
    -e GALLIUM_DRIVER=llvmpipe \
    -e MESA_GL_VERSION_OVERRIDE=3.3 \
    flutter-linux-test bash -c "
        echo '🔧 Configurando entorno...' && 
        export DISPLAY=:99 &&
        export LIBGL_ALWAYS_SOFTWARE=1 &&
        export GALLIUM_DRIVER=llvmpipe &&
        
        echo '🖥️  Iniciando Xvfb (servidor X virtual)...' &&
        Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
        XVFB_PID=\$! &&
        sleep 3 &&
        
        if ! kill -0 \$XVFB_PID 2>/dev/null; then
            echo '❌ Error: Xvfb no se pudo iniciar' &&
            cat /tmp/xvfb.log &&
            exit 1
        fi &&
        
        echo '🔐 Iniciando x11vnc (servidor VNC)...' &&
        x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared -rfbport 5900 -bg -o /tmp/x11vnc.log &&
        sleep 3 &&
        
        if ! pgrep -x x11vnc > /dev/null; then
            echo '❌ Error: x11vnc no se pudo iniciar' &&
            cat /tmp/x11vnc.log &&
            exit 1
        fi &&
        
        echo '🪟 Iniciando window manager (fluxbox)...' &&
        fluxbox > /tmp/fluxbox.log 2>&1 &
        sleep 2 &&
        
        echo '✅ Servidores iniciados correctamente' &&
        echo '   - Xvfb: display :99' &&
        echo '   - x11vnc: puerto 5900' &&
        echo '   - Fluxbox: window manager' &&
        echo '' &&
        echo '📱 Conéctate con un cliente VNC a: localhost:5900' &&
        echo '   (Usa TigerVNC o Screen Sharing: vnc://localhost:5900)' &&
        echo '' &&
        echo '🚀 Ejecutando aplicación Flutter...' &&
        cd /app &&
        flutter pub get > /dev/null 2>&1 &&
        flutter run --release -d linux
        
        # Mantener el contenedor corriendo
        wait
    "

echo ""
echo "✅ Aplicación finalizada"

