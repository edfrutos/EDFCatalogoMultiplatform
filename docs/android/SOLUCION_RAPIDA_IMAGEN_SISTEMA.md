# ⚡ Solución Rápida: Missing System Image

## 🎯 Tu Situación

- **Arquitectura:** Apple Silicon (arm64) ✅
- **Emulador:** Pixel 3a API 36
- **Problema:** Falta la imagen del sistema **arm64-v8a**

## 🚀 Solución en 3 Pasos

### Paso 1: Abrir Device Manager
```
Tools → Device Manager
```

### Paso 2: Descargar la Imagen
1. En Device Manager, junto al error "Missing system image", verás un icono **⬇️ (Download)**
2. Haz clic en el icono de descarga
3. Se abrirá un diálogo para seleccionar la imagen del sistema

### Paso 3: Seleccionar la Imagen Correcta
Para tu Mac Apple Silicon, selecciona:
- **Google APIs ARM 64 v8a System Image** (API 34 o 33)
- O **Google Play ARM 64 v8a System Image** (API 34 o 33) - Recomendado

Haz clic en **"Download"** y espera a que se complete (varios minutos, ~2-3 GB).

---

## ✅ Verificación

Una vez completada la descarga:
- El error desaparece en Device Manager
- El emulador muestra "Ready"
- Puedes hacer clic en **▶️ (Play)** para iniciarlo

---

## 🔄 Alternativa: Crear Nuevo Emulador

Si prefieres crear un nuevo emulador:

1. **Device Manager** → **Create Device**
2. Selecciona **Pixel 5** o **Pixel 6**
3. Selecciona una imagen que esté **instalada** (con ✅)
4. Recomendado: **API 33** o **API 34** con **Google Play ARM 64 v8a**
5. Asigna un nombre y haz clic en **"Finish"**
6. Haz clic en **▶️ (Play)** para iniciarlo

---

## 📚 Más Información

Para detalles completos, consulta:
- **`SOLUCION_IMAGEN_SISTEMA_EMULADOR.md`** - Guía completa

---

**¡Listo para resolver!** 🚀

