# 📱 Cómo Iniciar el Emulador en Android Studio

## 🎯 Método 1: Desde Device Manager (Recomendado)

### Paso 1: Abrir Device Manager

1. **Abrir Android Studio**
   - Asegúrate de que el proyecto esté abierto

2. **Abrir Device Manager**
   - Opción A: En la barra de herramientas superior, haz clic en el icono de **dispositivo** 📱
   - Opción B: **Tools** → **Device Manager**
   - Opción C: En la barra lateral derecha, busca el icono de **Device Manager**

### Paso 2: Seleccionar un Emulador

1. **Ver Lista de Emuladores**
   - En Device Manager, verás una lista de dispositivos virtuales (AVD)
   - Si no hay emuladores, verás un botón **"Create Device"**

2. **Emulador Disponible: Pixel_3a_API_36**
   - Busca **Pixel_3a_API_36** en la lista
   - O cualquier otro emulador que tengas configurado

### Paso 3: Iniciar el Emulador

1. **Hacer Clic en el Botón Play**
   - Junto al nombre del emulador, verás un botón **▶️ (Play)**
   - Haz clic en este botón para iniciar el emulador

2. **Esperar a que se Inicie**
   - El emulador comenzará a cargarse
   - Verás una ventana del emulador que se abre
   - Puede tardar **1-2 minutos** en iniciarse completamente
   - Verás la pantalla de inicio de Android cuando esté listo

### Paso 4: Verificar que Está Listo

1. **Pantalla del Emulador**
   - Deberías ver la pantalla de inicio de Android
   - El emulador debe estar desbloqueado (pantalla principal visible)

2. **Estado en Device Manager**
   - En Device Manager, el emulador debería mostrar **"Running"** en verde
   - El botón cambiará a **⏸️ (Pause)** cuando esté ejecutándose

---

## 🎯 Método 2: Desde la Terminal Integrada

### Paso 1: Abrir Terminal Integrada

1. **Abrir Terminal**
   - **View** → **Tool Windows** → **Terminal**
   - O presiona: `Alt + F12` (Windows/Linux) o `Option + F12` (macOS)

### Paso 2: Listar Emuladores Disponibles

```bash
# Listar emuladores disponibles
flutter emulators
```

Deberías ver algo como:
```
2 available emulators:

Id                  • Name            • Manufacturer • Platform
apple_ios_simulator • iOS Simulator   • Apple        • ios
Pixel_3a_API_36     • Pixel 3a API 36 • Google       • android
```

### Paso 3: Iniciar el Emulador

```bash
# Iniciar el emulador específico
flutter emulators --launch Pixel_3a_API_36
```

O usando adb directamente:
```bash
# Listar AVDs disponibles
emulator -list-avds

# Iniciar el emulador
emulator -avd Pixel_3a_API_36 &
```

---

## 🎯 Método 3: Crear un Nuevo Emulador (Si no Tienes Ninguno)

### Paso 1: Abrir Device Manager

1. **Abrir Device Manager**
   - **Tools** → **Device Manager**
   - O haz clic en el icono de dispositivo en la barra de herramientas

### Paso 2: Crear un Nuevo Dispositivo Virtual (AVD)

1. **Hacer Clic en "Create Device"**
   - En Device Manager, haz clic en el botón **"Create Device"**
   - O **"+"** en la esquina superior izquierda

### Paso 3: Seleccionar un Dispositivo

1. **Elegir un Dispositivo**
   - Selecciona un dispositivo de la lista (ej: **Pixel 5**, **Pixel 6**, **Nexus 5X**)
   - Haz clic en **"Next"**

### Paso 4: Seleccionar una Imagen del Sistema

1. **Elegir una Imagen del Sistema**
   - Selecciona una imagen del sistema (ej: **API 33**, **API 34**)
   - Si no está instalada, verás un botón **"Download"** junto a la imagen
   - Haz clic en **"Download"** si es necesario (puede tardar varios minutos)
   - Haz clic en **"Next"**

### Paso 5: Configurar el AVD

1. **Configurar el AVD**
   - **AVD Name:** Asigna un nombre (ej: `Pixel_5_API_33`)
   - **Startup orientation:** Selecciona **Portrait** (vertical) o **Landscape** (horizontal)
   - **Graphics:** Selecciona **Automatic** (recomendado) o **Hardware - GLES 2.0**
   - Haz clic en **"Finish"**

### Paso 6: Iniciar el Nuevo Emulador

1. **Iniciar el Emulador**
   - El nuevo emulador aparecerá en la lista de Device Manager
   - Haz clic en el botón **▶️ (Play)** para iniciarlo

---

## ⚠️ Solución de Problemas

### Problema 1: "No emulators found"

**Solución:**
1. Verifica que tienes el Android SDK instalado:
   - **File** → **Settings** → **Appearance & Behavior** → **System Settings** → **Android SDK**
   - Verifica que **Android SDK Platform-Tools** está instalado

2. Crea un nuevo emulador usando Device Manager (Método 3)

### Problema 2: El emulador no inicia

**Solución:**
1. Verifica que tienes suficiente memoria RAM disponible
2. Cierra otras aplicaciones que estén consumiendo memoria
3. Reinicia Android Studio
4. Intenta iniciar el emulador desde la terminal:
   ```bash
   emulator -avd Pixel_3a_API_36 -verbose
   ```
   Esto mostrará mensajes de error detallados

### Problema 3: El emulador se cuelga o es muy lento

**Solución:**
1. Reduce la RAM asignada al emulador:
   - En Device Manager, haz clic en el icono de **⚙️ (Settings)** junto al emulador
   - Reduce la **RAM** asignada (ej: de 2048 MB a 1536 MB)

2. Habilita la aceleración por hardware:
   - Verifica que **HAXM** (Intel) o **Hypervisor Framework** (Apple Silicon) está instalado
   - En macOS con Apple Silicon, la aceleración debería estar habilitada automáticamente

3. Usa un emulador con menos recursos:
   - Crea un emulador con una imagen del sistema más antigua (ej: API 30 en lugar de API 34)

### Problema 4: "emulator command not found"

**Solución:**
1. Verifica que el Android SDK está en tu PATH:
   ```bash
   echo $ANDROID_HOME
   ```
   Debería mostrar: `/Users/edefrutos/Library/Android/sdk`

2. Agrega el emulador al PATH:
   ```bash
   export PATH=$ANDROID_HOME/emulator:$PATH
   ```

3. O usa la ruta completa:
   ```bash
   $ANDROID_HOME/emulator/emulator -avd Pixel_3a_API_36
   ```

### Problema 5: El emulador aparece pero no se conecta

**Solución:**
1. Verifica que el emulador está completamente iniciado (pantalla de Android visible)
2. Verifica la conexión con adb:
   ```bash
   adb devices
   ```
   Deberías ver el emulador en la lista

3. Reinicia el servidor adb:
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```

---

## 📋 Verificación Rápida

### Verificar que el Emulador Está Ejecutándose

1. **En Device Manager**
   - El emulador debería mostrar **"Running"** en verde
   - El botón debería cambiar a **⏸️ (Pause)**

2. **Desde la Terminal**
   ```bash
   # Ver dispositivos conectados
   flutter devices
   
   # O con adb
   adb devices
   ```
   Deberías ver el emulador en la lista

3. **En Android Studio**
   - En el dropdown de dispositivos (barra superior), el emulador debería aparecer
   - Debería estar seleccionado automáticamente

---

## 🎯 Comandos Útiles

### Listar Emuladores Disponibles

```bash
# Con Flutter
flutter emulators

# Con adb
emulator -list-avds
```

### Iniciar Emulador desde Terminal

```bash
# Con Flutter
flutter emulators --launch Pixel_3a_API_36

# Con emulator directamente
emulator -avd Pixel_3a_API_36 &

# Con ruta completa
$ANDROID_HOME/emulator/emulator -avd Pixel_3a_API_36 &
```

### Detener Emulador

```bash
# Cerrar el emulador desde la interfaz gráfica
# O desde la terminal:
adb -s emulator-5554 emu kill
```

### Ver Logs del Emulador

```bash
# Ver logs en tiempo real
adb logcat

# Filtrar logs específicos
adb logcat | grep -i "flutter"
```

---

## 📝 Notas Importantes

### Primera Iniciación

- La primera vez que inicies un emulador puede tardar **2-3 minutos**
- Esto es normal debido a la inicialización del sistema Android
- Las siguientes iniciaciones serán más rápidas (30-60 segundos)

### Recursos del Sistema

- Los emuladores consumen bastante RAM y CPU
- Asegúrate de tener al menos **4 GB de RAM disponibles**
- Cierra otras aplicaciones pesadas si es necesario

### Aceleración por Hardware

- En **macOS con Apple Silicon**, la aceleración está habilitada automáticamente
- En **Intel Mac**, necesitas **HAXM** instalado
- En **Linux**, necesitas **KVM** configurado
- En **Windows**, necesitas **HAXM** o **Hyper-V** (Windows 10 Pro)

### Emuladores Recomendados

- **Pixel 5** o **Pixel 6** - Buen equilibrio entre rendimiento y características
- **Pixel 3a** - Más ligero, ideal para desarrollo
- **Nexus 5X** - Muy ligero, pero con características limitadas

---

## ✅ Checklist

Antes de ejecutar la aplicación, verifica:

- [ ] El emulador está iniciado y visible
- [ ] La pantalla del emulador muestra Android (no está en negro)
- [ ] El emulador está desbloqueado (pantalla principal visible)
- [ ] En Device Manager, el emulador muestra **"Running"**
- [ ] En el dropdown de dispositivos de Android Studio, el emulador aparece
- [ ] `flutter devices` o `adb devices` muestra el emulador

---

## 🚀 Siguiente Paso

Una vez que el emulador esté ejecutándose:

1. **Ejecutar la Aplicación**
   - En Android Studio, haz clic en **▶️ (Run)**
   - O presiona `Shift + F10` (Windows/Linux) o `Control + R` (macOS)

2. **Verificar que Funciona**
   - La aplicación debería instalarse e iniciarse automáticamente
   - Verás los logs en la pestaña **"Run"** en la parte inferior

---

## 📚 Referencias

- **`COMO_EJECUTAR_ANDROID_STUDIO.md`** - Guía completa de Android Studio
- **`GUIA_RAPIDA_ANDROID_STUDIO.md`** - Guía rápida de referencia
- **`INSTRUCCIONES_EJECUTAR_ANDROID.md`** - Instrucciones generales

---

**Última actualización:** Noviembre 2024

