#!/bin/bash

# Script para construir la aplicación Linux para una máquina real Ubuntu
# Este script NO afecta las construcciones de macOS/iOS ni el setup de Docker
# Uso: ./scripts/build_linux_release.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🐧 Construyendo aplicación Linux para Ubuntu real..."
echo "📁 Directorio del proyecto: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# Detectar el sistema operativo
OS="$(uname -s)"
case "$OS" in
    Linux*)
        IS_LINUX=true
        ;;
    Darwin*)
        IS_LINUX=false
        IS_MACOS=true
        ;;
    *)
        IS_LINUX=false
        IS_MACOS=false
        ;;
esac

# Verificar que Flutter está disponible
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter no está instalado o no está en el PATH"
    exit 1
fi

# Si estamos en macOS, no podemos construir Linux directamente
if [ "$IS_MACOS" = true ]; then
    echo "⚠️  Estás en macOS. Flutter no puede construir Linux directamente desde macOS."
    echo ""
    echo "📋 Opciones disponibles:"
    echo ""
    echo "   1. Construir usando Docker (recomendado):"
    echo "      ./scripts/build_linux_release_docker.sh"
    echo ""
    echo "   2. Construir en una máquina Linux real:"
    echo "      - Transfiere el proyecto a una máquina Ubuntu"
    echo "      - Ejecuta este mismo script allí"
    echo ""
    echo "   3. Construir manualmente en Docker:"
    echo "      docker-compose -f docker/docker-compose.linux-test.yml run --rm flutter-linux-test \\"
    echo "        bash -c 'cd /app && flutter build linux --release'"
    echo ""
    read -p "¿Deseas construir usando Docker ahora? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        # Llamar al script de Docker si existe, o construir directamente
        if [ -f "$SCRIPT_DIR/build_linux_release_docker.sh" ]; then
            exec "$SCRIPT_DIR/build_linux_release_docker.sh"
        else
            echo "🔨 Construyendo en Docker..."
            docker-compose -f docker/docker-compose.linux-test.yml run --rm \
                -v "$PROJECT_DIR:/app" \
                -w /app \
                flutter-linux-test \
                bash -c "flutter build linux --release && cp -r build/linux/*/release/bundle /app/build/linux_release/bundle 2>/dev/null || cp -r build/linux/arm64/release/bundle /app/build/linux_release/bundle"
            exit $?
        fi
    else
        echo "❌ Build cancelado. Usa una de las opciones mencionadas."
        exit 1
    fi
fi

# Verificar que Linux desktop está habilitado (solo en Linux)
if [ "$IS_LINUX" = true ]; then
    if ! flutter config | grep -q "enable-linux-desktop.*true"; then
        echo "⚠️  Linux desktop no está habilitado. Habilitándolo..."
        flutter config --enable-linux-desktop
    fi
fi

# Verificar dependencias
echo "📦 Verificando dependencias..."
flutter pub get

# Limpiar builds anteriores de Linux (solo Linux, no otras plataformas)
echo "🧹 Limpiando builds anteriores de Linux..."
if [ -d "$PROJECT_DIR/build/linux" ]; then
    rm -rf "$PROJECT_DIR/build/linux"
    echo "   ✅ Builds de Linux limpiados"
fi

# Crear directorio de salida
OUTPUT_DIR="$PROJECT_DIR/build/linux_release"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "🔨 Construyendo aplicación Linux en modo Release..."
echo "   Esto puede tardar varios minutos..."
echo ""

# Construir la aplicación en modo Release
# Usamos --release para crear un build optimizado para producción
flutter build linux --release

# Verificar que el build se completó correctamente
BUNDLE_DIR="$PROJECT_DIR/build/linux/arm64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
    # Intentar con x64 si arm64 no existe
    BUNDLE_DIR="$PROJECT_DIR/build/linux/x64/release/bundle"
fi

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ Error: No se encontró el bundle de Linux"
    echo "   Buscado en: $PROJECT_DIR/build/linux/*/release/bundle"
    exit 1
fi

echo ""
echo "✅ Build completado exitosamente"
echo "📦 Bundle ubicado en: $BUNDLE_DIR"
echo ""

# Copiar el bundle al directorio de salida
echo "📋 Copiando bundle al directorio de salida..."
cp -r "$BUNDLE_DIR" "$OUTPUT_DIR/"

# Crear un archivo README con instrucciones
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
EOF

echo "📄 Archivo README creado: $OUTPUT_DIR/README_LINUX_INSTALL.md"
echo ""

# Mostrar información del bundle
echo "📊 Información del build:"
echo "   - Ubicación: $OUTPUT_DIR/bundle"
echo "   - Ejecutable: $OUTPUT_DIR/bundle/edfcatalogomultiplatform"
if [ -f "$OUTPUT_DIR/bundle/.env" ]; then
    echo "   - ✅ Archivo .env incluido"
else
    echo "   - ⚠️  Archivo .env no encontrado (puede ser necesario)"
fi

echo ""
echo "✅ Build de Linux completado exitosamente!"
echo ""
echo "📦 Para distribuir:"
echo "   1. Comprime la carpeta 'bundle' dentro de '$OUTPUT_DIR'"
echo "   2. Transfiere el archivo comprimido a tu máquina Ubuntu"
echo "   3. Sigue las instrucciones en README_LINUX_INSTALL.md"
echo ""
echo "💡 Nota: Este build NO afecta las construcciones de macOS/iOS"
echo "   El Docker setup también permanece intacto"

