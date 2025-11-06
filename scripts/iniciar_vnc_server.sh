#!/bin/bash

# Script para iniciar solo el servidor VNC (sin ejecutar Flutter automáticamente)
# Útil para conectarse primero y luego ejecutar Flutter manualmente

set -e

echo "🚀 Iniciando servidor VNC..."

cd "$(dirname "$0")/.."

# Verificar si el puerto 5900 está en uso
if lsof -i :5900 >/dev/null 2>&1; then
    echo "⚠️  El puerto 5900 ya está en uso. Deteniendo contenedores anteriores..."
    docker-compose -f docker/docker-compose.linux-test.yml down 2>/dev/null || true
    sleep 2
fi

echo "🐳 Iniciando contenedor con Xvfb y VNC..."
echo ""
echo "📋 El servidor VNC estará disponible en: localhost:5900"
echo "💡 Conéctate con TigerVNC o Screen Sharing antes de continuar"
echo ""

# Iniciar el contenedor en modo interactivo
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
        
        echo '🖥️  Iniciando Xvfb...' &&
        Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
        sleep 3 &&
        
        echo '🔐 Iniciando x11vnc...' &&
        x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -forever -shared -rfbport 5900 -bg -o /tmp/x11vnc.log &&
        sleep 3 &&
        
        echo '🪟 Iniciando fluxbox...' &&
        fluxbox > /tmp/fluxbox.log 2>&1 &
        sleep 2 &&
        
        echo '' &&
        echo '✅ Servidor VNC iniciado correctamente!' &&
        echo '   📱 Conéctate a: localhost:5900' &&
        echo '' &&
        echo '💡 Una vez conectado, puedes ejecutar:' &&
        echo '   cd /app && flutter run --release -d linux' &&
        echo '' &&
        echo '⏳ Manteniendo contenedor activo... (Ctrl+C para salir)' &&
        
        # Mantener el contenedor corriendo
        tail -f /dev/null
    "

