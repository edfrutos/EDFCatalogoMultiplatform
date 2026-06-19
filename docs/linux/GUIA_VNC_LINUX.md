# 🖥️ Ejecutar Aplicación Linux con GUI usando VNC

Esta guía te muestra cómo ejecutar la aplicación Flutter Linux con GUI usando Xvfb + VNC dentro de Docker.

## ✅ Ventajas de esta Solución

- ✅ Funciona completamente dentro de Docker
- ✅ No requiere X11 forwarding desde macOS
- ✅ No requiere XQuartz
- ✅ Funciona con software rendering (llvmpipe)
- ✅ Acceso remoto vía VNC

## 📋 Requisitos

1. **Docker** instalado y corriendo
2. **Cliente VNC** (opcional, puedes usar Screen Sharing de macOS)

## 🚀 Pasos Rápidos

### 1. Reconstruir la imagen Docker (primera vez)

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
docker-compose -f docker/docker-compose.linux-test.yml build
```

### 2. Ejecutar el script

```bash
./scripts/ejecutar_linux_vnc.sh
```

### 3. Conectarse con VNC

El script iniciará automáticamente:
- Xvfb (servidor X virtual en display :99)
- x11vnc (servidor VNC en puerto 5900)
- Fluxbox (window manager)
- La aplicación Flutter

**Conectarse con Screen Sharing de macOS:**
1. Presiona `Cmd+K` (o ve a Finder > Ir > Conectar al servidor)
2. Ingresa: `vnc://localhost:5900`
3. Presiona Enter

**O usar un cliente VNC:**
- **RealVNC Viewer**: https://www.realvnc.com/download/viewer/
- **TigerVNC**: `brew install --cask tigervnc-viewer`
- Luego conecta a: `localhost:5900`

## 🔧 Cómo Funciona

1. **Xvfb** crea un servidor X virtual (display :99) que funciona completamente en software
2. **x11vnc** comparte ese display vía VNC en el puerto 5900
3. **Fluxbox** proporciona un window manager básico
4. **Flutter** ejecuta la aplicación en el display virtual
5. **VNC** permite ver y controlar la aplicación desde macOS

## 🎨 Resolución de Pantalla

Por defecto, la resolución es **1920x1080**. Puedes cambiarla editando el script:

```bash
# En scripts/ejecutar_linux_vnc.sh, línea con Xvfb:
Xvfb :99 -screen 0 1920x1080x24 ...
# Cambia 1920x1080 por la resolución deseada, ej: 1280x720
```

## 🐛 Solución de Problemas

### El puerto 5900 ya está en uso

```bash
# Ver qué está usando el puerto
lsof -i :5900

# O cambiar el puerto en docker-compose.linux-test.yml
ports:
  - "5901:5900"  # Usa 5901 en lugar de 5900
```

### La aplicación no aparece en VNC

1. Verifica que el contenedor esté corriendo: `docker ps`
2. Verifica los logs: `docker logs <container_id>`
3. Intenta reconectar el cliente VNC

### Performance lenta

- Es normal, estamos usando software rendering
- La aplicación funcionará, pero puede ser más lenta que en hardware real
- Para mejor performance, usa una máquina Linux real

## 📝 Notas

- La aplicación se ejecuta en modo **release** para mejor performance
- El contenedor se detendrá cuando cierres la aplicación Flutter
- Puedes usar `Ctrl+C` para detener el script
- Los cambios en el código se reflejarán al recompilar

## 🔄 Comparación con Otras Soluciones

| Solución | Requiere | Funciona en macOS | Performance |
|----------|----------|-------------------|-------------|
| X11 Forwarding | XQuartz | ❌ Limitado | ⚠️ Problemas OpenGL |
| VNC (esta) | Solo Docker | ✅ Sí | ✅ Funciona |
| Linux Real | Máquina Linux | N/A | ✅✅ Excelente |
| VM Linux | VirtualBox/VMware | ✅ Sí | ✅✅ Buena |

## 💡 Recomendación

Para **desarrollo y pruebas rápidas**: Usa esta solución VNC
Para **producción y testing real**: Usa una máquina Linux real

