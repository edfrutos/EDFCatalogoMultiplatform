# ⚡ Guía Rápida: Iniciar Emulador en Android Studio

## 🎯 Método Rápido (3 Pasos)

### 1️⃣ Abrir Device Manager
```
Tools → Device Manager
```
O haz clic en el icono 📱 en la barra de herramientas

### 2️⃣ Seleccionar Emulador
En la lista, encuentra **Pixel_3a_API_36** (o el que tengas)

### 3️⃣ Iniciar Emulador
Haz clic en el botón **▶️ (Play)** junto al emulador

⏱️ **Espera 1-2 minutos** hasta que veas la pantalla de Android

---

## 📱 Verificación Rápida

### ¿Está el emulador listo?

✅ **Sí, está listo si:**
- La pantalla del emulador muestra Android (no está en negro)
- El emulador está desbloqueado (pantalla principal visible)
- En Device Manager muestra **"Running"** en verde
- En el dropdown de dispositivos aparece el emulador

❌ **No, no está listo si:**
- La pantalla está en negro
- Aparece "Starting..." o "Booting..."
- No aparece en `flutter devices` o `adb devices`

---

## 🔧 Desde Terminal (Alternativa)

```bash
# Listar emuladores disponibles
flutter emulators

# Iniciar emulador específico
flutter emulators --launch Pixel_3a_API_36
```

---

## ⚠️ Si No Tienes Emuladores

### Crear un Nuevo Emulador

1. **Device Manager** → **Create Device**
2. Selecciona un dispositivo (ej: **Pixel 5**)
3. Selecciona una imagen del sistema (ej: **API 33**)
4. Si no está instalada, haz clic en **"Download"**
5. Asigna un nombre y haz clic en **"Finish"**
6. Haz clic en **▶️ (Play)** para iniciarlo

---

## 🐛 Solución de Problemas Rápida

### El emulador no inicia
- Verifica que tienes suficiente RAM (al menos 4 GB disponibles)
- Cierra otras aplicaciones pesadas
- Reinicia Android Studio

### El emulador es muy lento
- Reduce la RAM asignada en Device Manager (⚙️ Settings)
- Usa un emulador con menos recursos (ej: API 30 en lugar de API 34)

### "emulator command not found"
```bash
# Verificar ANDROID_HOME
echo $ANDROID_HOME

# Agregar al PATH
export PATH=$ANDROID_HOME/emulator:$PATH
```

---

## ✅ Checklist Pre-Ejecución

Antes de ejecutar la aplicación:

- [ ] Emulador iniciado y visible
- [ ] Pantalla de Android visible (no negra)
- [ ] Emulador desbloqueado
- [ ] Device Manager muestra **"Running"**
- [ ] Dropdown de dispositivos muestra el emulador

---

## 🚀 Siguiente Paso

Una vez que el emulador esté listo:

1. **Selecciona el emulador** en el dropdown de dispositivos
2. **Ejecuta la aplicación** con **▶️ (Run)** o `Shift + F10`

---

## 📚 Más Información

Para detalles completos, consulta:
- **`INICIAR_EMULADOR_ANDROID_STUDIO.md`** - Guía completa paso a paso
- **`COMO_EJECUTAR_ANDROID_STUDIO.md`** - Guía completa de Android Studio

---

**¡Listo para ejecutar!** 🚀

