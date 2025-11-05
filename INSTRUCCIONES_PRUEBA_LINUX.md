# 🧪 Instrucciones para Probar la Aplicación en Linux

Esta guía te ayudará a compilar y probar la aplicación EDFCatalogoMultiplatform en Linux.

## 📋 Verificación Previa

Antes de comenzar, verifica que tienes todo configurado:

### 1. Verificar Flutter y Linux Desktop

```bash
flutter doctor -v
```

Deberías ver:
- ✅ `enable-linux-desktop` en la lista de features
- ✅ Sin errores relacionados con Linux

### 2. Verificar dependencias del sistema

```bash
# Verificar CMake
cmake --version  # Debe ser 3.13 o superior

# Verificar GTK3
pkg-config --modversion gtk+-3.0  # Debe mostrar una versión

# Verificar GCC
gcc --version
```

### 3. Verificar archivo .env

```bash
# Asegúrate de que el archivo .env existe en la raíz del proyecto
ls -la .env
```

## 🏗️ Compilación

### Opción 1: Compilación en modo Debug (recomendado para pruebas)

```bash
# Limpiar builds previos (opcional)
flutter clean

# Compilar en modo debug
flutter build linux --debug
```

**Salida esperada:**
- El bundle se creará en: `build/linux/x64/bundle/` (o `arm64` según tu arquitectura)
- Deberías ver el mensaje: `✅ .env file will be copied to bundle` durante la compilación

### Opción 2: Compilación en modo Release

```bash
flutter build linux --release
```

### Opción 3: Ejecutar directamente (sin compilar bundle completo)

```bash
flutter run -d linux
```

**Nota:** Esta opción es útil para desarrollo rápido, pero el `.env` debe estar en la raíz del proyecto.

## ✅ Verificación Post-Compilación

### 1. Verificar que el bundle se creó

```bash
ls -la build/linux/x64/bundle/
```

Deberías ver:
- `edfcatalogomultiplatform` (ejecutable)
- `data/` (directorio con assets)
- `lib/` (directorio con librerías)
- `.env` (archivo de variables de entorno) ✅

### 2. Verificar que el .env se copió

```bash
# Verificar en la raíz del bundle
ls -la build/linux/x64/bundle/.env

# Verificar en el directorio de datos
ls -la build/linux/x64/bundle/data/.env

# Ver contenido del .env (sin mostrar valores sensibles)
head -n 1 build/linux/x64/bundle/.env
```

## 🚀 Ejecución

### Ejecutar desde el bundle

```bash
cd build/linux/x64/bundle
./edfcatalogomultiplatform
```

### O ejecutar desde cualquier ubicación

```bash
# Desde la raíz del proyecto
./build/linux/x64/bundle/edfcatalogomultiplatform
```

## 🔍 Verificación de Logs

Al ejecutar la aplicación, deberías ver en la consola:

```
🔍 Buscando .env en Linux (PRIORIDAD):
   - /ruta/completa/al/bundle/.env
   - /ruta/completa/al/bundle/data/.env
   - ...
✅ Variables cargadas con dotenv desde: /ruta/al/bundle/.env
📋 Variables cargadas: X
```

### Verificar que MongoDB se conecta

Deberías ver logs indicando conexión exitosa a MongoDB:
```
✅ Conectado a MongoDB
```

### Verificar que S3 funciona (si está configurado)

Si `USE_S3=true` en el `.env`, deberías poder subir archivos sin errores.

## 🐛 Solución de Problemas

### Problema: "CMake not found"

**Solución:**
```bash
# Ubuntu/Debian
sudo apt-get install cmake

# Fedora/RHEL
sudo dnf install cmake
```

### Problema: "GTK+ not found"

**Solución:**
```bash
# Ubuntu/Debian
sudo apt-get install libgtk-3-dev

# Fedora/RHEL
sudo dnf install gtk3-devel
```

### Problema: ".env no encontrado" en los logs

**Verificaciones:**
1. ¿El `.env` existe en la raíz del proyecto?
   ```bash
   ls -la .env
   ```

2. ¿Se copió al bundle durante el build?
   ```bash
   ls -la build/linux/x64/bundle/.env
   ```

3. Si no se copió, cópialo manualmente:
   ```bash
   cp .env build/linux/x64/bundle/.env
   cp .env build/linux/x64/bundle/data/.env
   ```

### Problema: "No se puede conectar a MongoDB"

**Verificaciones:**
1. Verifica que `MONGO_URI` está correcto en el `.env`
2. Verifica que la aplicación puede acceder a la red:
   ```bash
   # Probar conexión a MongoDB desde terminal
   curl -v <MONGO_URI>
   ```
3. Verifica el firewall:
   ```bash
   sudo ufw status
   ```

### Problema: "Error al cargar .env"

**Solución:**
- Verifica que el `.env` tiene el formato correcto (líneas `KEY=VALUE`)
- Verifica que no hay caracteres especiales problemáticos
- Verifica los permisos del archivo:
  ```bash
  chmod 644 build/linux/x64/bundle/.env
  ```

## 📝 Checklist de Pruebas

- [ ] La aplicación compila sin errores
- [ ] El `.env` se copia al bundle durante el build
- [ ] La aplicación se ejecuta sin crashes
- [ ] Los logs muestran que el `.env` se carga correctamente
- [ ] La conexión a MongoDB funciona
- [ ] El login funciona
- [ ] Se pueden crear y editar catálogos
- [ ] Se pueden subir archivos (si S3 está configurado)
- [ ] Los backups funcionan (Google Drive)
- [ ] El panel de administración funciona
- [ ] La interfaz se ve correctamente (responsive)

## 🎯 Comandos Rápidos

```bash
# Compilar y ejecutar en un solo comando
flutter build linux --debug && ./build/linux/x64/bundle/edfcatalogomultiplatform

# Limpiar y recompilar
flutter clean && flutter build linux --debug

# Ver logs mientras ejecutas
./build/linux/x64/bundle/edfcatalogomultiplatform 2>&1 | tee app.log
```

## 📞 Reportar Problemas

Si encuentras algún problema:

1. **Captura los logs completos:**
   ```bash
   ./build/linux/x64/bundle/edfcatalogomultiplatform > app.log 2>&1
   ```

2. **Verifica la versión de Flutter:**
   ```bash
   flutter --version
   ```

3. **Verifica la arquitectura:**
   ```bash
   uname -m
   ```

4. **Incluye información del sistema:**
   ```bash
   lsb_release -a  # Ubuntu/Debian
   cat /etc/os-release  # Otros
   ```

