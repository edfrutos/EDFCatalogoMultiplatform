# 🔧 Solución: Missing System Image for Emulator

## ⚠️ Problema Detectado

El emulador **Pixel 3a API 36** muestra el error:
```
Missing system image for Google APIs arm64-v8a Pixel 3a API 36
```

Esto significa que falta la imagen del sistema Android necesaria para ejecutar el emulador.

---

## 🎯 Solución 1: Descargar la Imagen del Sistema (Recomendado)

### Paso 1: Abrir SDK Manager

1. **En Android Studio:**
   - **Tools** → **SDK Manager**
   - O haz clic en el icono de **⚙️ (Settings)** en la barra de herramientas
   - Selecciona **"SDK Manager"**

### Paso 2: Instalar la Imagen del Sistema

1. **Seleccionar la Pestaña "SDK Platforms"**
   - En SDK Manager, haz clic en la pestaña **"SDK Platforms"**

2. **Buscar Android 14.0 (API 34) o Android 13.0 (API 33)**
   - Marca la casilla **"Show Package Details"** (abajo a la derecha)
   - Busca **"Android 14.0 (API 34)"** o **"Android 13.0 (API 33)"**
   - Expande la sección para ver las imágenes disponibles

3. **Seleccionar la Imagen del Sistema**
   - Para **arm64-v8a** (Apple Silicon Mac):
     - Marca: **"Android SDK Platform 34"** o **"Android SDK Platform 33"**
     - Marca: **"Google APIs ARM 64 v8a System Image"** o **"Google Play ARM 64 v8a System Image"**
   - Para **x86_64** (Intel Mac):
     - Marca: **"Android SDK Platform 34"** o **"Android SDK Platform 33"**
     - Marca: **"Google APIs x86_64 System Image"** o **"Google Play x86_64 System Image"**

4. **Aplicar Cambios**
   - Haz clic en **"Apply"** o **"OK"**
   - Se iniciará la descarga (puede tardar varios minutos, 1-3 GB)

### Paso 3: Verificar la Instalación

1. **Cerrar SDK Manager**
   - Una vez completada la descarga, cierra el SDK Manager

2. **Verificar en Device Manager**
   - **Tools** → **Device Manager**
   - El emulador **Pixel 3a API 36** debería mostrar que está listo
   - El error de "Missing system image" debería desaparecer

---

## 🎯 Solución 2: Crear un Nuevo Emulador con Imagen Instalada

### Paso 1: Abrir Device Manager

1. **Abrir Device Manager**
   - **Tools** → **Device Manager**

### Paso 2: Crear un Nuevo Dispositivo Virtual (AVD)

1. **Hacer Clic en "Create Device"**
   - Haz clic en el botón **"Create Device"** o **"+"**

2. **Seleccionar un Dispositivo**
   - Selecciona un dispositivo (ej: **Pixel 5**, **Pixel 6**, **Pixel 3a**)
   - Haz clic en **"Next"**

3. **Seleccionar una Imagen del Sistema**
   - Verás una lista de imágenes del sistema disponibles
   - **Importante:** Solo aparecen las imágenes que están instaladas
   - Si no ves ninguna, necesitas instalar una (ver Solución 1)
   - Selecciona una imagen que tenga el icono **"Download"** marcado como instalado ✅
   - Ejemplos:
     - **API 34 (Android 14.0)** - Recomendado (más reciente)
     - **API 33 (Android 13.0)** - Estable
     - **API 30 (Android 11.0)** - Más ligero
   - Haz clic en **"Next"**

4. **Configurar el AVD**
   - **AVD Name:** Asigna un nombre (ej: `Pixel_5_API_34`)
   - **Startup orientation:** Selecciona **Portrait** (vertical)
   - **Graphics:** Selecciona **Automatic** (recomendado)
   - Haz clic en **"Finish"**

### Paso 3: Iniciar el Nuevo Emulador

1. **Iniciar el Emulador**
   - El nuevo emulador aparecerá en Device Manager
   - Haz clic en el botón **▶️ (Play)** para iniciarlo
   - Espera 1-2 minutos hasta que se inicie

---

## 🎯 Solución 3: Descargar desde Device Manager (Más Rápido)

### Paso 1: Abrir Device Manager

1. **Abrir Device Manager**
   - **Tools** → **Device Manager**

### Paso 2: Descargar la Imagen desde el Error

1. **Hacer Clic en el Icono de Descarga**
   - Junto al error "Missing system image", verás un icono de **⬇️ (Download)**
   - Haz clic en este icono

2. **Seleccionar la Imagen del Sistema**
   - Se abrirá un diálogo para seleccionar la imagen del sistema
   - Selecciona la imagen apropiada para tu sistema:
     - **arm64-v8a** para Apple Silicon Mac
     - **x86_64** para Intel Mac
   - Haz clic en **"Download"** o **"Next"**

3. **Esperar la Descarga**
   - Se iniciará la descarga (puede tardar varios minutos)
   - Verás el progreso en una barra de progreso

4. **Verificar que se Instaló**
   - Una vez completada la descarga, el error debería desaparecer
   - El emulador debería estar listo para usar

---

## 🔍 Verificar tu Arquitectura

Para saber qué imagen del sistema necesitas:

### Apple Silicon Mac (M1, M2, M3, etc.)
```bash
# Verificar arquitectura
uname -m
# Debería mostrar: arm64
```
**Necesitas:** Imagen **arm64-v8a**

### Intel Mac
```bash
# Verificar arquitectura
uname -m
# Debería mostrar: x86_64
```
**Necesitas:** Imagen **x86_64**

---

## 📋 Imágenes Recomendadas

### Para Apple Silicon Mac (arm64-v8a)
- **Google APIs ARM 64 v8a System Image** (API 34 o 33)
- **Google Play ARM 64 v8a System Image** (API 34 o 33)

### Para Intel Mac (x86_64)
- **Google APIs x86_64 System Image** (API 34 o 33)
- **Google Play x86_64 System Image** (API 34 o 33)

### Nota sobre Google APIs vs Google Play
- **Google APIs:** Incluye APIs de Google, pero no Google Play Store
- **Google Play:** Incluye Google Play Store (recomendado para desarrollo)

---

## ⚠️ Solución de Problemas

### Problema 1: "No se puede descargar la imagen"

**Solución:**
1. Verifica tu conexión a internet
2. Verifica que tienes suficiente espacio en disco (al menos 3-5 GB)
3. Intenta descargar desde SDK Manager en lugar de Device Manager
4. Reinicia Android Studio

### Problema 2: "La descarga se interrumpe"

**Solución:**
1. Verifica tu conexión a internet
2. Intenta descargar nuevamente
3. Si persiste, descarga manualmente desde:
   - https://developer.android.com/studio/run/emulator

### Problema 3: "La imagen se descarga pero el error persiste"

**Solución:**
1. Cierra y reinicia Android Studio
2. Verifica en SDK Manager que la imagen está instalada:
   - **Tools** → **SDK Manager** → **SDK Platforms**
   - Busca la imagen y verifica que está marcada como instalada ✅
3. Si no está instalada, instálala manualmente desde SDK Manager

### Problema 4: "No sé qué imagen descargar"

**Solución:**
1. Verifica tu arquitectura (ver sección "Verificar tu Arquitectura")
2. Para Apple Silicon Mac: Descarga **arm64-v8a**
3. Para Intel Mac: Descarga **x86_64**
4. Recomendación: Descarga **API 33** o **API 34** (las más recientes y estables)

---

## 🎯 Método Más Rápido (Recomendado)

1. **Abrir Device Manager**
   - **Tools** → **Device Manager**

2. **Hacer Clic en el Icono de Descarga**
   - Junto al error "Missing system image", haz clic en **⬇️ (Download)**

3. **Seleccionar la Imagen**
   - Selecciona la imagen apropiada para tu sistema
   - Haz clic en **"Download"**

4. **Esperar la Descarga**
   - Espera a que se complete la descarga (varios minutos)

5. **Iniciar el Emulador**
   - Una vez completada, haz clic en **▶️ (Play)** para iniciar el emulador

---

## ✅ Verificación Final

Una vez que la imagen esté instalada:

- [ ] El error "Missing system image" desaparece en Device Manager
- [ ] El emulador muestra "Ready" o está listo para ejecutarse
- [ ] Puedes hacer clic en **▶️ (Play)** sin errores
- [ ] El emulador se inicia correctamente (pantalla de Android visible)

---

## 🚀 Siguiente Paso

Una vez que el emulador esté listo:

1. **Iniciar el Emulador**
   - Haz clic en **▶️ (Play)** en Device Manager
   - Espera 1-2 minutos hasta que se inicie

2. **Ejecutar la Aplicación**
   - Selecciona el emulador en el dropdown de dispositivos
   - Haz clic en **▶️ (Run)** o presiona `Shift + F10`

---

## 📚 Referencias

- **`INICIAR_EMULADOR_ANDROID_STUDIO.md`** - Guía completa de emuladores
- **`GUIA_RAPIDA_EMULADOR.md`** - Guía rápida de referencia
- **`COMO_EJECUTAR_ANDROID_STUDIO.md`** - Guía completa de Android Studio

---

**Última actualización:** Noviembre 2024

