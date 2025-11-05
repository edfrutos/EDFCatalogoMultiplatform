# 🐧 Guía de Configuración para Linux

Esta guía explica cómo configurar y ejecutar la aplicación EDFCatalogoMultiplatform en Linux.

## 📋 Requisitos Previos

1. **Flutter SDK** instalado y configurado
2. **CMake** (versión 3.13 o superior)
3. **GTK3** development libraries
4. **pkg-config**
5. **GCC** o **Clang** compilador

### Instalación de dependencias en Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y \
    cmake \
    ninja-build \
    libgtk-3-dev \
    pkg-config \
    gcc \
    build-essential
```

### Instalación de dependencias en Fedora/RHEL:

```bash
sudo dnf install -y \
    cmake \
    ninja-build \
    gtk3-devel \
    pkg-config \
    gcc
```

## 🔧 Configuración

### 1. Habilitar soporte Linux en Flutter

```bash
flutter config --enable-linux-desktop
```

### 2. Verificar que Linux está habilitado

```bash
flutter doctor
```

Deberías ver `enable-linux-desktop` en la lista de features.

### 3. Archivo .env

El archivo `.env` debe estar en la raíz del proyecto. Durante el build, se copiará automáticamente al bundle de la aplicación.

**Ubicaciones donde se busca el `.env` (en orden de prioridad):**

1. `bundle/.env` (mismo directorio que el ejecutable)
2. `bundle/data/.env` (directorio de datos del bundle)
3. Directorio raíz del proyecto (desarrollo con `flutter run`)

## 🏗️ Compilación

### Compilación en modo Debug:

```bash
flutter build linux --debug
```

El bundle se creará en: `build/linux/<arch>/bundle/`

### Compilación en modo Release:

```bash
flutter build linux --release
```

### Ejecutar directamente (sin compilar bundle):

```bash
flutter run -d linux
```

## 📦 Instalación del Bundle

Después de compilar, puedes ejecutar la aplicación directamente desde el bundle:

```bash
cd build/linux/x64/bundle
./edfcatalogomultiplatform
```

O instalar el bundle completo:

```bash
# Copiar el bundle a un directorio permanente
sudo cp -r build/linux/x64/bundle /opt/edfcatalogomultiplatform

# Crear enlace simbólico al ejecutable
sudo ln -s /opt/edfcatalogomultiplatform/edfcatalogomultiplatform /usr/local/bin/edfcatalogomultiplatform

# Copiar archivo .desktop (opcional)
sudo cp linux/com.edfcatalogo.edfcatalogomultiplatform.desktop /usr/share/applications/
```

## 🔍 Verificación

### Verificar que el .env se copió correctamente:

```bash
ls -la build/linux/x64/bundle/.env
ls -la build/linux/x64/bundle/data/.env
```

### Verificar que la aplicación puede encontrar el .env:

Ejecuta la aplicación y revisa los logs en la consola. Deberías ver:

```
🔍 Buscando .env en Linux (PRIORIDAD):
   - /ruta/al/bundle/.env
✅ Variables cargadas con dotenv desde: /ruta/al/bundle/.env
```

## 🐛 Solución de Problemas

### Error: "CMake not found"

Instala CMake:
```bash
sudo apt-get install cmake  # Ubuntu/Debian
sudo dnf install cmake      # Fedora/RHEL
```

### Error: "GTK+ not found"

Instala las librerías de desarrollo GTK3:
```bash
sudo apt-get install libgtk-3-dev  # Ubuntu/Debian
sudo dnf install gtk3-devel        # Fedora/RHEL
```

### Error: ".env not found"

1. Verifica que el archivo `.env` existe en la raíz del proyecto
2. Verifica que CMake copió el archivo durante el build
3. Ejecuta la aplicación desde el bundle compilado, no desde `flutter run`

### La aplicación no encuentra MongoDB

1. Verifica que `MONGO_URI` está correctamente configurado en `.env`
2. Verifica que la aplicación puede acceder a la red (firewall)
3. Revisa los logs de la aplicación para ver dónde busca el `.env`

## 📝 Notas Adicionales

- La aplicación busca el `.env` en múltiples ubicaciones automáticamente
- Durante el desarrollo con `flutter run`, el `.env` se busca en la raíz del proyecto
- En producción, el `.env` debe estar en el bundle o en el directorio de datos
- El archivo `.desktop` permite que la aplicación aparezca en el menú de aplicaciones

## 🚀 Próximos Pasos

Después de configurar Linux, puedes:

1. Probar la aplicación en modo debug
2. Compilar para release
3. Crear un paquete .deb o .rpm para distribución
4. Configurar auto-actualizaciones (opcional)

