# 📱 Guía: Seleccionar Dispositivo Emulador en Android Studio

## 🎯 Situación Actual

Estás en el diálogo **"Select Remote Devices"** que muestra dispositivos Google Pixel disponibles. Este diálogo te permite seleccionar o crear un dispositivo virtual para ejecutar tu aplicación.

## ✅ Recomendaciones para tu Mac Apple Silicon (arm64)

### Opción 1: Pixel 5 o Pixel 6 (Recomendado)

**¿Por qué?**
- Buen equilibrio entre rendimiento y características
- Imágenes del sistema ampliamente disponibles
- Bien soportadas en Apple Silicon

**Configuración sugerida:**
- **Dispositivo:** Pixel 5 o Pixel 6
- **API Level:** 33 o 34 (Android 13 o 14)
- **Imagen del Sistema:** Google Play ARM 64 v8a System Image

### Opción 2: Pixel 7 o Pixel 8

**¿Por qué?**
- Dispositivos más recientes
- Mejor soporte para características modernas
- Buena compatibilidad con Apple Silicon

**Configuración sugerida:**
- **Dispositivo:** Pixel 7 o Pixel 8
- **API Level:** 34 (Android 14)
- **Imagen del Sistema:** Google Play ARM 64 v8a System Image

### Opción 3: Pixel 9 o Pixel 10 (Más Reciente)

**¿Por qué?**
- Dispositivos más nuevos
- API Level 35 o 36 (Android más reciente)
- Puede requerir más recursos

**Configuración sugerida:**
- **Dispositivo:** Pixel 9 o Pixel 10
- **API Level:** 35 o 36
- **Imagen del Sistema:** Google Play ARM 64 v8a System Image

## 🚫 Evitar (Por Ahora)

### Pixel 3a API 36
- **Problema:** Falta la imagen del sistema (como viste anteriormente)
- **Solución:** Descargar la imagen del sistema primero, o usar otro dispositivo

### Dispositivos con API muy antiguas (API 30 o inferior)
- **Problema:** Pueden tener problemas de compatibilidad
- **Solución:** Usar API 33 o superior

## 🎯 Pasos para Crear un Emulador

### Paso 1: Seleccionar un Dispositivo en el Diálogo

1. **En el diálogo "Select Remote Devices":**
   - Busca un dispositivo Pixel (ej: **Pixel 5**, **Pixel 6**, **Pixel 7**)
   - Verifica que tenga un **API Level** de 33 o 34
   - Marca la casilla del dispositivo que quieras usar
   - Haz clic en **"Confirm"**

### Paso 2: Si el Dispositivo No Está Disponible Localmente

Si seleccionas un dispositivo que no tiene la imagen del sistema instalada:

1. **Se abrirá un diálogo para descargar la imagen**
2. **Selecciona la imagen apropiada:**
   - Para Apple Silicon: **Google Play ARM 64 v8a System Image**
   - O **Google APIs ARM 64 v8a System Image**
3. **Haz clic en "Download"**
4. **Espera a que se complete la descarga** (varios minutos)

### Paso 3: Configurar el AVD

1. **Se abrirá el asistente de configuración del AVD**
2. **Configuración recomendada:**
   - **AVD Name:** `Pixel_5_API_34` (o el nombre que prefieras)
   - **Startup orientation:** **Portrait** (vertical)
   - **Graphics:** **Automatic** (recomendado)
   - **RAM:** 2048 MB o 1536 MB (según tu disponibilidad)
3. **Haz clic en "Finish"**

### Paso 4: Iniciar el Emulador

1. **En Device Manager:**
   - El nuevo emulador aparecerá en la lista
   - Haz clic en el botón **▶️ (Play)** para iniciarlo
   - Espera 1-2 minutos hasta que se inicie

## 📋 Configuración Recomendada por Nivel de API

### API 34 (Android 14) - Más Recomendado
- **Dispositivo:** Pixel 5, Pixel 6, Pixel 7, Pixel 8
- **Imagen:** Google Play ARM 64 v8a System Image
- **Ventajas:** Estable, bien soportado, características modernas

### API 33 (Android 13) - Estable
- **Dispositivo:** Pixel 5, Pixel 6
- **Imagen:** Google Play ARM 64 v8a System Image
- **Ventajas:** Muy estable, ampliamente probado

### API 35-36 (Android más reciente) - Experimental
- **Dispositivo:** Pixel 9, Pixel 10
- **Imagen:** Google Play ARM 64 v8a System Image
- **Ventajas:** Características más recientes
- **Desventajas:** Puede tener problemas de compatibilidad

## 🔍 Verificar Qué Imágenes Tienes Instaladas

### Desde SDK Manager

1. **Tools** → **SDK Manager**
2. **Pestaña "SDK Platforms"**
3. **Marca "Show Package Details"**
4. **Busca las imágenes instaladas:**
   - Busca **"Google Play ARM 64 v8a System Image"** o **"Google APIs ARM 64 v8a System Image"**
   - Las imágenes instaladas aparecerán con una ✅
   - Las no instaladas aparecerán vacías

### Desde Device Manager

1. **Tools** → **Device Manager**
2. **Create Device**
3. **Selecciona un dispositivo**
4. **En la lista de imágenes del sistema:**
   - Las imágenes instaladas aparecerán con ✅
   - Las no instaladas mostrarán un icono de descarga ⬇️

## ⚠️ Solución de Problemas

### Problema: "No system images available"

**Solución:**
1. Descarga una imagen del sistema desde SDK Manager:
   - **Tools** → **SDK Manager** → **SDK Platforms**
   - Marca **"Show Package Details"**
   - Busca y marca **"Google Play ARM 64 v8a System Image"** (API 33 o 34)
   - Haz clic en **"Apply"** para descargar

### Problema: "The emulator process was killed"

**Solución:**
1. Reduce la RAM asignada al emulador:
   - En Device Manager, haz clic en el icono **⚙️ (Settings)** del emulador
   - Reduce la **RAM** de 2048 MB a 1536 MB o menos
2. Cierra otras aplicaciones que consuman mucha memoria
3. Reinicia Android Studio

### Problema: "The emulator is very slow"

**Solución:**
1. Verifica que la aceleración por hardware está habilitada:
   - En macOS con Apple Silicon, debería estar habilitada automáticamente
2. Reduce la resolución del emulador:
   - En Device Manager, edita el emulador (icono de lápiz)
   - Reduce la resolución de pantalla
3. Usa un dispositivo más ligero:
   - Pixel 5 en lugar de Pixel 8
   - API 33 en lugar de API 34

## ✅ Checklist para Seleccionar un Dispositivo

Antes de seleccionar un dispositivo, verifica:

- [ ] El dispositivo tiene un **API Level** de 33 o 34 (recomendado)
- [ ] La imagen del sistema está instalada (aparece con ✅)
- [ ] La imagen es para **ARM 64 v8a** (para Apple Silicon)
- [ ] El dispositivo tiene características adecuadas para tu aplicación
- [ ] Tienes suficiente RAM disponible (al menos 4 GB)

## 🚀 Siguiente Paso

Una vez que hayas creado y configurado el emulador:

1. **Iniciar el Emulador**
   - En Device Manager, haz clic en **▶️ (Play)**
   - Espera 1-2 minutos hasta que se inicie

2. **Ejecutar la Aplicación**
   - Selecciona el emulador en el dropdown de dispositivos
   - Haz clic en **▶️ (Run)** o presiona `Shift + F10`

## 📚 Referencias

- **`SOLUCION_IMAGEN_SISTEMA_EMULADOR.md`** - Solución completa para imágenes del sistema
- **`INICIAR_EMULADOR_ANDROID_STUDIO.md`** - Guía completa de emuladores
- **`GUIA_RAPIDA_EMULADOR.md`** - Guía rápida de referencia

---

**Última actualización:** Noviembre 2024

