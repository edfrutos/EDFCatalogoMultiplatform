# ⚠️ Limitaciones de Ejecutar Flutter Linux GUI en Docker desde macOS

## 🔴 Problema Conocido

La aplicación Flutter se **compila correctamente** en Docker, pero **no se puede ejecutar con GUI** desde macOS debido a limitaciones de OpenGL/GLX.

### Errores Observados

```
libGL error: No matching fbConfigs or visuals found
libGL error: failed to load driver: swrast
Gdk-CRITICAL: gdk_gl_context_make_current: assertion 'GDK_IS_GL_CONTEXT (context)' failed
```

### Causa Raíz

1. **Flutter en Linux requiere OpenGL** para renderizar la interfaz gráfica
2. **XQuartz en macOS** no soporta bien GLX indirecto a través de X11 forwarding
3. **Software rendering** (llvmpipe) no funciona correctamente a través de X11 forwarding desde macOS

## ✅ Lo que SÍ Funciona

### 1. Compilación en Docker

La aplicación **se compila perfectamente** en Docker:

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
docker-compose -f docker/docker-compose.linux-test.yml build
docker-compose -f docker/docker-compose.linux-test.yml run --rm \
  flutter-linux-test \
  bash -c "flutter build linux --release && echo '✅ Build exitoso'"
```

### 2. Verificar el Bundle

Puedes verificar que el bundle se creó correctamente:

```bash
docker-compose -f docker/docker-compose.linux-test.yml run --rm \
  flutter-linux-test \
  bash -c "ls -la build/linux/arm64/release/bundle/"
```

## 🚀 Alternativas para Ejecutar la GUI

### Opción 1: Máquina Linux Real (Recomendado)

La mejor opción es ejecutar la aplicación en una máquina Linux real:

1. **Copiar el bundle** compilado desde Docker
2. **Ejecutar en Linux** con hardware OpenGL real

```bash
# En macOS: copiar el bundle
docker cp <container_id>:/app/build/linux/arm64/release/bundle ./linux-bundle

# Transferir a máquina Linux (usando scp, USB, etc.)
scp -r ./linux-bundle user@linux-machine:/tmp/

# En Linux: ejecutar
cd /tmp/linux-bundle
./edfcatalogomultiplatform
```

### Opción 2: Máquina Virtual Linux

Usar una VM Linux (VirtualBox, VMware, Parallels) con aceleración 3D habilitada:

1. Instalar Ubuntu/Debian en la VM
2. Habilitar aceleración 3D en la configuración de la VM
3. Compilar y ejecutar dentro de la VM

### Opción 3: Servicios Cloud con GUI

Usar servicios como:
- **GitHub Codespaces** con Linux
- **AWS EC2** con acceso gráfico
- **Google Cloud** con acceso gráfico

### Opción 4: Xvfb + VNC ✅ (IMPLEMENTADO - Recomendado)

**Esta solución ya está implementada y lista para usar.**

Usar Xvfb dentro del contenedor y acceder vía VNC:

```bash
# Ejecutar el script
./scripts/ejecutar_linux_vnc.sh

# Conectarse con Screen Sharing de macOS (Cmd+K)
# Ingresa: vnc://localhost:5900
```

**Ventajas:**
- ✅ Funciona completamente dentro de Docker
- ✅ No requiere XQuartz
- ✅ No requiere X11 forwarding
- ✅ Funciona con software rendering

**Ver guía completa:** `GUIA_VNC_LINUX.md`

## 📊 Estado Actual

| Funcionalidad | Estado | Notas |
|--------------|--------|-------|
| Compilación en Docker | ✅ Funciona | Se compila correctamente |
| Bundle Linux | ✅ Funciona | Se genera correctamente |
| Ejecución GUI en Docker (X11 forwarding) | ❌ No funciona | Limitación de OpenGL/GLX |
| Ejecución GUI en Docker (VNC) | ✅ Funciona | Usa Xvfb + VNC |
| Ejecución GUI en Linux real | ✅ Funciona | Requiere máquina Linux |

## 💡 Recomendación

Para **desarrollo y pruebas**:
- Usa Docker con **VNC** (Xvfb) para ejecutar con GUI ✅ **IMPLEMENTADO**
- O usa una **máquina Linux real** o **VM** para mejor performance

Para **producción**:
- Compila en Docker o CI/CD
- Distribuye el bundle a usuarios Linux
- Los usuarios ejecutan en sus máquinas Linux con OpenGL hardware

## 🔧 Scripts Disponibles

- `scripts/ejecutar_linux_gui.sh` - Intenta ejecutar con GUI (limitado en macOS)
- `docker/docker-compose.linux-test.yml` - Configuración Docker
- `docker/Dockerfile.linux-test` - Imagen Docker con Flutter

## 📝 Notas Técnicas

- La compilación funciona porque no requiere OpenGL
- La ejecución falla porque Flutter requiere OpenGL para renderizar
- XQuartz en macOS no soporta GLX indirecto correctamente
- Software rendering (llvmpipe) no funciona a través de X11 forwarding desde macOS

