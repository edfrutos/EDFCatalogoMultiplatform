# 🐧 Build de Linux para Ubuntu Real

Este documento explica cómo construir la aplicación Linux para ejecutarla en una máquina real Ubuntu.

## ⚠️ Importante

- **Este build NO afecta las construcciones de macOS/iOS** - Son completamente independientes
- **El Docker setup permanece intacto** - Los scripts de Docker siguen funcionando normalmente
- Este build es para **máquinas Linux reales**, no para Docker

## 🚀 Construcción Rápida

```bash
./scripts/build_linux_release.sh
```

Este script:
1. Verifica que Flutter esté configurado para Linux
2. Limpia solo los builds de Linux (no toca macOS/iOS)
3. Construye la aplicación en modo Release
4. Crea un bundle portable en `build/linux_release/bundle`
5. Genera un README con instrucciones de instalación

## 📋 Requisitos Previos

### En macOS (donde construyes):

1. Flutter instalado y configurado
2. Linux desktop habilitado:
   ```bash
   flutter config --enable-linux-desktop
   ```

### En Ubuntu (donde ejecutarás):

- Ubuntu 20.04 o superior
- GTK 3.0 o superior
- Dependencias del sistema (ver README_LINUX_INSTALL.md en el bundle)

## 📦 Estructura del Build

Después de ejecutar el script, encontrarás:

```
build/linux_release/
├── bundle/                          # Bundle completo de la aplicación
│   ├── edfcatalogomultiplatform     # Ejecutable principal
│   ├── lib/                         # Bibliotecas necesarias
│   ├── data/                        # Datos y assets
│   ├── .env                         # Variables de entorno (si existe)
│   └── ...
└── README_LINUX_INSTALL.md          # Instrucciones de instalación
```

## 🔧 Opciones de Build

### Build Release (Recomendado para producción)

```bash
./scripts/build_linux_release.sh
```

### Build Manual

Si prefieres construir manualmente:

```bash
# Limpiar solo Linux
rm -rf build/linux

# Build Release
flutter build linux --release

# El bundle estará en: build/linux/arm64/release/bundle
# o en: build/linux/x64/release/bundle (dependiendo de tu arquitectura)
```

### Build Debug (para desarrollo)

```bash
flutter build linux --debug
```

## 📤 Distribución

1. **Comprimir el bundle:**
   ```bash
   cd build/linux_release
   tar -czf edfcatalogomultiplatform-linux.tar.gz bundle/
   ```

2. **Transferir a Ubuntu:**
   - Usa scp, rsync, o cualquier método de transferencia
   - Ejemplo con scp:
     ```bash
     scp edfcatalogomultiplatform-linux.tar.gz usuario@ubuntu-maquina:/ruta/destino/
     ```

3. **En Ubuntu, extraer y ejecutar:**
   ```bash
   tar -xzf edfcatalogomultiplatform-linux.tar.gz
   cd bundle
   ./edfcatalogomultiplatform
   ```

## 🔍 Verificación

Para verificar que el build no afectó otras plataformas:

```bash
# Verificar que macOS sigue funcionando
flutter build macos --debug

# Verificar que iOS sigue funcionando
flutter build ios --debug --no-codesign

# Verificar que Docker sigue funcionando
./scripts/flutter_run_linux.sh
```

## 🐛 Solución de Problemas

### Error: "Linux desktop not enabled"

```bash
flutter config --enable-linux-desktop
flutter doctor
```

### Error: "Missing dependencies"

En Ubuntu, instala las dependencias:
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

### El ejecutable no funciona en Ubuntu

1. Verifica que tiene permisos de ejecución:
   ```bash
   chmod +x edfcatalogomultiplatform
   ```

2. Verifica las dependencias:
   ```bash
   ldd edfcatalogomultiplatform
   ```

3. Ejecuta con logs para ver errores:
   ```bash
   ./edfcatalogomultiplatform 2>&1 | tee app.log
   ```

## 📝 Notas

- El build de Linux es independiente de macOS/iOS
- Los archivos de configuración de Linux están en `linux/`
- El archivo `.env` se copia automáticamente al bundle si existe
- El build crea un bundle portable que no requiere instalación

## 🔗 Enlaces Relacionados

- [README_LINUX.md](README_LINUX.md) - Información sobre ejecutar Linux con Docker
- [docker/](docker/) - Configuración de Docker para testing
- [scripts/flutter_run_linux.sh](scripts/flutter_run_linux.sh) - Script para ejecutar en Docker

