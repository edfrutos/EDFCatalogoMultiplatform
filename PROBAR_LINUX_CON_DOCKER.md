# 🐳 Probar la Aplicación en Linux usando Docker

Esta guía te ayudará a probar la aplicación Flutter en Linux usando Docker, sin necesidad de tener una máquina Linux instalada.

## 📋 Requisitos Previos

1. **Docker** instalado y funcionando
2. **Docker Compose** (opcional, pero recomendado)
3. **X11/XQuartz** (solo si quieres ver la GUI de la aplicación)

## 🔍 Verificar Docker

### Verificar que Docker está instalado:

```bash
docker --version
docker-compose --version  # o docker compose version (Docker Compose V2)
```

### Verificar que Docker está corriendo:

```bash
docker ps
```

Si ves un error, inicia Docker Desktop (macOS/Windows) o el servicio Docker (Linux).

## 🚀 Opción 1: Usar Docker Compose (Recomendado)

### 1. Construir la imagen Docker:

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
docker-compose -f docker/docker-compose.linux-test.yml build
```

### 2. Ejecutar el contenedor:

```bash
docker-compose -f docker/docker-compose.linux-test.yml run --rm flutter-linux-test bash
```

### 3. Dentro del contenedor, verificar Flutter:

```bash
flutter doctor -v
```

### 4. Compilar la aplicación:

```bash
flutter build linux --debug
```

### 5. Verificar que el .env se copió:

```bash
ls -la build/linux/x64/bundle/.env
cat build/linux/x64/bundle/.env | head -n 1
```

## 🚀 Opción 2: Usar Docker directamente

### 1. Construir la imagen:

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
docker build -f docker/Dockerfile.linux-test -t flutter-linux-test .
```

### 2. Ejecutar el contenedor:

```bash
docker run -it --rm \
  -v $(pwd):/app \
  -v $(pwd)/.env:/app/.env:ro \
  -w /app \
  flutter-linux-test \
  bash
```

### 3. Dentro del contenedor:

```bash
# Verificar Flutter
flutter doctor -v

# Compilar
flutter build linux --debug

# Verificar .env
ls -la build/linux/x64/bundle/.env
```

## 🖥️ Ejecutar la GUI (Opcional)

**Nota:** Para ejecutar la aplicación con GUI desde Docker, necesitas X11 forwarding.

### En macOS:

1. **Instalar XQuartz:**
   ```bash
   brew install --cask xquartz
   ```

2. **Iniciar XQuartz:**
   ```bash
   open -a XQuartz
   ```

3. **Permitir conexiones de red en XQuartz:**
   - Abre XQuartz > Preferences > Security
   - Marca "Allow connections from network clients"
   - Reinicia XQuartz

4. **Configurar DISPLAY:**
   ```bash
   export DISPLAY=host.docker.internal:0
   xhost + 127.0.0.1
   ```

5. **Ejecutar el contenedor con X11:**
   ```bash
   docker run -it --rm \
     -v $(pwd):/app \
     -v $(pwd)/.env:/app/.env:ro \
     -e DISPLAY=host.docker.internal:0 \
     --network host \
     flutter-linux-test \
     bash
   ```

### En Linux:

```bash
docker run -it --rm \
  -v $(pwd):/app \
  -v $(pwd)/.env:/app/.env:ro \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  flutter-linux-test \
  bash
```

## 🧪 Probar la Compilación sin GUI

Si solo quieres verificar que la aplicación compila correctamente (sin ejecutarla):

```bash
# Entrar al contenedor
docker-compose -f docker/docker-compose.linux-test.yml run --rm flutter-linux-test bash

# Dentro del contenedor
flutter build linux --debug

# Verificar que se creó el bundle
ls -la build/linux/x64/bundle/

# Verificar que el .env está ahí
ls -la build/linux/x64/bundle/.env

# Verificar los logs de compilación (buscar mensaje sobre .env)
# Deberías ver: "✅ .env file will be copied to bundle"
```

## 📝 Verificar que el .env se Carga Correctamente

### Opción A: Verificar logs de compilación

Busca en los logs de compilación:
```
✅ .env file will be copied to bundle
```

### Opción B: Verificar archivos en el bundle

```bash
# Dentro del contenedor
cd build/linux/x64/bundle
ls -la .env
ls -la data/.env
head -n 1 .env  # Ver primera línea (sin mostrar valores sensibles)
```

### Opción C: Crear un script de prueba simple

Crea un archivo `test_env.dart`:

```dart
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  print('🔍 Buscando .env...');
  
  final paths = [
    '.env',
    'build/linux/x64/bundle/.env',
    'build/linux/x64/bundle/data/.env',
  ];
  
  for (final path in paths) {
    if (File(path).existsSync()) {
      print('✅ Encontrado: $path');
      try {
        await dotenv.load(fileName: path);
        print('✅ Cargado correctamente');
        print('📋 Variables: ${dotenv.env.keys.length}');
        break;
      } catch (e) {
        print('❌ Error cargando: $e');
      }
    } else {
      print('❌ No encontrado: $path');
    }
  }
}
```

Ejecutar:
```bash
dart test_env.dart
```

## 🐛 Solución de Problemas

### Problema: "Cannot connect to Docker daemon"

**Solución:**
```bash
# Iniciar Docker Desktop (macOS/Windows)
# O iniciar el servicio Docker (Linux)
sudo systemctl start docker
```

### Problema: "Permission denied" al construir

**Solución:**
```bash
# Agregar tu usuario al grupo docker (Linux)
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar
```

### Problema: "X11 forwarding failed"

**Solución:**
- Si no necesitas ver la GUI, puedes compilar sin ejecutar
- Si necesitas la GUI, verifica la configuración de XQuartz (macOS) o X11 (Linux)

### Problema: ".env no se copia"

**Solución:**
1. Verifica que el `.env` existe en la raíz del proyecto:
   ```bash
   ls -la .env
   ```

2. Verifica que CMake lo detectó durante el build (busca en los logs)

3. Cópialo manualmente si es necesario:
   ```bash
   # Dentro del contenedor
   cp .env build/linux/x64/bundle/.env
   cp .env build/linux/x64/bundle/data/.env
   ```

## 🎯 Comandos Rápidos

```bash
# Compilar en Docker (todo en uno)
docker-compose -f docker/docker-compose.linux-test.yml run --rm \
  flutter-linux-test \
  bash -c "flutter build linux --debug && ls -la build/linux/x64/bundle/.env"

# Entrar al contenedor y trabajar interactivamente
docker-compose -f docker/docker-compose.linux-test.yml run --rm \
  flutter-linux-test \
  bash

# Limpiar y reconstruir
docker-compose -f docker/docker-compose.linux-test.yml down
docker-compose -f docker/docker-compose.linux-test.yml build --no-cache
```

## 📊 Verificar el Sistema Actual

Para verificar tu sistema actual:

```bash
# Ver sistema operativo
uname -a

# Verificar Docker
docker --version
docker ps

# Verificar si estás en macOS
sw_vers  # Solo en macOS
```

## 💡 Recomendación

Para probar la compilación de Linux, usa Docker (sin necesidad de GUI). Para probar la ejecución completa, necesitarías una máquina Linux real o configurar X11 forwarding.

**Prueba rápida:**
```bash
# Construir y compilar en Docker
docker-compose -f docker/docker-compose.linux-test.yml build
docker-compose -f docker/docker-compose.linux-test.yml run --rm \
  flutter-linux-test \
  bash -c "flutter build linux --debug && echo '✅ Build completado' && ls -la build/linux/x64/bundle/.env"
```

