#!/bin/bash

# Script para construir la aplicación Linux usando Docker
# Útil cuando estás en macOS y quieres construir para Linux
# Uso: ./scripts/build_linux_release_docker.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🐧 Construyendo aplicación Linux usando Docker..."
echo "📁 Directorio del proyecto: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# Verificar que Docker está corriendo
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Error: Docker no está corriendo. Por favor inicia Docker Desktop."
    exit 1
fi

# Verificar que docker-compose está disponible
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Error: docker-compose no está instalado"
    exit 1
fi

# Crear directorio de salida
OUTPUT_DIR="$PROJECT_DIR/build/linux_release"
mkdir -p "$OUTPUT_DIR"

echo "🔨 Construyendo aplicación Linux en Docker (modo Release)..."
echo "   Esto puede tardar varios minutos..."
echo ""

# Construir la aplicación dentro del contenedor Docker
docker-compose -f docker/docker-compose.linux-test.yml run --rm \
    -v "$PROJECT_DIR:/app" \
    -w /app \
    flutter-linux-test \
    bash -c "
        echo '📦 Instalando dependencias...'
        flutter pub get
        
        echo '🧹 Limpiando builds anteriores...'
        rm -rf build/linux
        
        echo '🔨 Construyendo en modo Release...'
        flutter build linux --release
        
        echo '✅ Build completado'
        
        # Encontrar el bundle (puede ser arm64 o x64)
        if [ -d 'build/linux/arm64/release/bundle' ]; then
            BUNDLE_SRC='build/linux/arm64/release/bundle'
        elif [ -d 'build/linux/x64/release/bundle' ]; then
            BUNDLE_SRC='build/linux/x64/release/bundle'
        else
            BUNDLE_SRC=\$(find build/linux -name 'bundle' -type d | head -1)
        fi
        
        if [ -z \"\$BUNDLE_SRC\" ] || [ ! -d \"\$BUNDLE_SRC\" ]; then
            echo '❌ Error: No se encontró el bundle'
            exit 1
        fi
        
        echo \"📦 Bundle encontrado en: \$BUNDLE_SRC\"
        echo '📋 Copiando bundle al directorio de salida...'
        cp -r \"\$BUNDLE_SRC\" /app/build/linux_release/
        
        echo '✅ Bundle copiado exitosamente'
    "

# Verificar que el bundle se copió correctamente
if [ ! -d "$OUTPUT_DIR/bundle" ]; then
    echo "❌ Error: El bundle no se copió correctamente"
    exit 1
fi

# Crear README con instrucciones
cat > "$OUTPUT_DIR/README_LINUX_INSTALL.md" << 'EOF'
# Instrucciones para instalar en Ubuntu

## Requisitos del sistema

- Ubuntu 20.04 o superior
- GTK 3.0 o superior
- Las siguientes dependencias del sistema:

```bash
sudo apt-get update
sudo apt-get install -y \
    libgtk-3-0 \
    libblkid1 \
    liblzma5 \
    libsecret-1-0 \
    libjson-c4 \
    libgconf-2-4
```

## Instalación

1. Copia la carpeta `bundle` completa a tu máquina Ubuntu
2. Navega al directorio `bundle`
3. Ejecuta la aplicación:

```bash
cd bundle
chmod +x edfcatalogomultiplatform
./edfcatalogomultiplatform
```

## Instalación permanente (opcional)

Para instalar la aplicación de forma permanente:

```bash
# Copiar el bundle a /opt
sudo cp -r bundle /opt/edfcatalogomultiplatform

# Crear un enlace simbólico para ejecutarlo desde cualquier lugar
sudo ln -s /opt/edfcatalogomultiplatform/edfcatalogomultiplatform /usr/local/bin/edfcatalogomultiplatform

# Copiar el archivo .desktop para que aparezca en el menú de aplicaciones
sudo cp com.edfcatalogo.edfcatalogomultiplatform.desktop /usr/share/applications/
```

## Notas

- Asegúrate de que el archivo `.env` esté presente en el directorio `bundle` si tu aplicación lo requiere
- La aplicación requiere conexión a internet para algunas funcionalidades
- Este build fue creado usando Docker desde macOS
EOF

echo ""
echo "✅ Build completado exitosamente!"
echo "📦 Bundle ubicado en: $OUTPUT_DIR/bundle"
echo ""
echo "📊 Información del build:"
echo "   - Ubicación: $OUTPUT_DIR/bundle"
echo "   - Ejecutable: $OUTPUT_DIR/bundle/edfcatalogomultiplatform"
if [ -f "$OUTPUT_DIR/bundle/.env" ]; then
    echo "   - ✅ Archivo .env incluido"
else
    echo "   - ⚠️  Archivo .env no encontrado (puede ser necesario)"
fi

echo ""
echo "📦 Para distribuir:"
echo "   1. Comprime la carpeta 'bundle' dentro de '$OUTPUT_DIR'"
echo "   2. Transfiere el archivo comprimido a tu máquina Ubuntu"
echo "   3. Sigue las instrucciones en README_LINUX_INSTALL.md"
echo ""
echo "💡 Nota: Este build NO afecta las construcciones de macOS/iOS"
echo "   El Docker setup también permanece intacto"

