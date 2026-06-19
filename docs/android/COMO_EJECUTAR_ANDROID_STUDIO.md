# 📱 Cómo Ejecutar la Aplicación desde Android Studio

## 🎯 Guía Paso a Paso

### Paso 1: Abrir el Proyecto en Android Studio

1. **Abre Android Studio**
   - Busca Android Studio en tus aplicaciones
   - O ejecuta desde la terminal: `open -a "Android Studio"`

2. **Abrir el Proyecto**
   - Opción A: Desde la pantalla de bienvenida
     - Haz clic en **"Open"** o **"Open an Existing Project"**
     - Navega a: `/Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform`
     - Selecciona la carpeta y haz clic en **"Open"**
   
   - Opción B: Desde el menú
     - **File** → **Open**
     - Selecciona: `/Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform`
     - Haz clic en **"Open"**

3. **Esperar a que se Indexe el Proyecto**
   - Android Studio comenzará a indexar el proyecto
   - Esto puede tardar 1-2 minutos la primera vez
   - Verás una barra de progreso en la parte inferior

### Paso 2: Configurar el SDK de Android (si es necesario)

1. **Verificar Configuración del SDK**
   - **File** → **Settings** (o **Preferences** en macOS)
   - Navega a: **Appearance & Behavior** → **System Settings** → **Android SDK**
   - Verifica que tienes instalado:
     - **Android SDK Platform 33** o superior
     - **Android SDK Build-Tools**
     - **Android SDK Platform-Tools**

2. **Verificar JDK**
   - **File** → **Settings** → **Build, Execution, Deployment** → **Build Tools** → **Gradle**
   - En **Gradle JDK**, selecciona: **JDK 17** o superior
   - Si no aparece, haz clic en **Download JDK** y selecciona versión 17

### Paso 3: Sincronizar el Proyecto con Gradle

1. **Sincronizar Gradle**
   - Android Studio mostrará una notificación en la parte superior: **"Gradle files have changed since last project sync"**
   - Haz clic en **"Sync Now"** o
   - **File** → **Sync Project with Gradle Files**
   - Espera a que termine la sincronización (puede tardar 2-3 minutos)

2. **Verificar que la Sincronización fue Exitosa**
   - En la parte inferior, verás: **"Gradle build finished"**
   - Si hay errores, revísalos en la pestaña **"Build"**

### Paso 4: Ejecutar el Script de Sincronización de Gradle (Opcional pero Recomendado)

1. **Abrir la Terminal Integrada**
   - **View** → **Tool Windows** → **Terminal**
   - O presiona: `Alt + F12` (Windows/Linux) o `Option + F12` (macOS)

2. **Ejecutar el Script**
   ```bash
   # Asegúrate de estar en la raíz del proyecto
   cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
   
   # Ejecutar el script (desde la raíz)
   ./android/sync_gradle_version.sh
   
   # O si estás en el directorio android/:
   # ./sync_gradle_version.sh
   ```

3. **Sincronizar Gradle de Nuevo**
   - **File** → **Sync Project with Gradle Files**

### Paso 5: Configurar un Emulador Android

#### Opción A: Usar un Emulador Existente

1. **Abrir Device Manager**
   - **Tools** → **Device Manager**
   - O haz clic en el icono de dispositivo en la barra de herramientas

2. **Iniciar un Emulador**
   - En la lista de dispositivos, encuentra **Pixel_3a_API_36** (o el que tengas)
   - Haz clic en el botón **▶️ (Play)** junto al emulador
   - Espera a que el emulador se inicie (puede tardar 1-2 minutos)

#### Opción B: Crear un Nuevo Emulador

1. **Abrir Device Manager**
   - **Tools** → **Device Manager**

2. **Crear un Nuevo Dispositivo Virtual (AVD)**
   - Haz clic en **"Create Device"**
   - Selecciona un dispositivo (ej: **Pixel 5**)
   - Haz clic en **"Next"**

3. **Seleccionar una Imagen del Sistema**
   - Selecciona una imagen del sistema (ej: **API 33** o **API 34**)
   - Si no está instalada, haz clic en **"Download"** junto a la imagen
   - Haz clic en **"Next"**

4. **Configurar el AVD**
   - Asigna un nombre (ej: **Pixel_5_API_33**)
   - Haz clic en **"Finish"**

5. **Iniciar el Emulador**
   - Haz clic en el botón **▶️ (Play)** junto al nuevo emulador

### Paso 6: Ejecutar la Aplicación

1. **Seleccionar el Dispositivo/Emulador**
   - En la barra de herramientas superior, verás un dropdown con dispositivos
   - Selecciona el emulador que acabas de iniciar (ej: **Pixel_3a_API_36**)

2. **Ejecutar la Aplicación**
   - Opción A: Haz clic en el botón **▶️ (Run)** en la barra de herramientas
   - Opción B: **Run** → **Run 'app'**
   - Opción C: Presiona `Shift + F10` (Windows/Linux) o `Control + R` (macOS)

3. **Esperar la Compilación**
   - Android Studio comenzará a compilar la aplicación
   - Verás el progreso en la pestaña **"Build"** en la parte inferior
   - La primera compilación puede tardar 3-5 minutos

4. **Verificar que la Aplicación se Ejecuta**
   - El emulador mostrará la aplicación
   - Los logs aparecerán en la pestaña **"Run"** en la parte inferior
   - Deberías ver mensajes como: `✅ Variables de entorno cargadas desde assets para Android`

### Paso 7: Verificar los Logs

1. **Abrir la Pestaña de Logs**
   - En la parte inferior, haz clic en la pestaña **"Run"** o **"Logcat"**

2. **Filtrar los Logs**
   - En Logcat, puedes filtrar por:
     - **Tag:** `flutter`
     - **Package:** `com.example.edfcatalogo_multiplatform`
     - **Level:** `Info`, `Debug`, `Error`

3. **Buscar Logs Importantes**
   - `✅ Variables de entorno cargadas desde assets para Android`
   - `📋 Variables cargadas: X`
   - `✅ Variables cargadas: MONGO_URI ✅ Cargada`

## 🔧 Configuración Adicional

### Configurar Hot Reload

1. **Habilitar Hot Reload**
   - Cuando la aplicación esté ejecutándose, verás opciones en la barra de herramientas:
     - **🔄 (Hot Reload)** - Recarga cambios sin reiniciar
     - **🔄 (Hot Restart)** - Reinicia la aplicación manteniendo el estado
     - **⏹️ (Stop)** - Detiene la aplicación

2. **Usar Hot Reload**
   - Haz cambios en el código
   - Presiona `Ctrl + S` (Windows/Linux) o `Cmd + S` (macOS) para guardar
   - Haz clic en **🔄 (Hot Reload)** o presiona `Ctrl + \` (Windows/Linux) o `Cmd + \` (macOS)

### Configurar el Debugger

1. **Establecer Breakpoints**
   - Haz clic en el margen izquierdo del editor (junto al número de línea)
   - Aparecerá un punto rojo (breakpoint)

2. **Ejecutar en Modo Debug**
   - **Run** → **Debug 'app'**
   - O presiona `Shift + F9` (Windows/Linux) o `Control + D` (macOS)

3. **Inspeccionar Variables**
   - Cuando la aplicación se detenga en un breakpoint, verás:
     - **Variables** - Variables locales y del alcance
     - **Watches** - Expresiones que quieres monitorear
     - **Call Stack** - Pila de llamadas

## ⚠️ Solución de Problemas

### Problema 1: "Gradle sync failed"

**Solución:**
1. Ejecuta el script de sincronización:
   ```bash
   ./android/sync_gradle_version.sh
   ```
2. Limpia el proyecto: **Build** → **Clean Project**
3. Sincroniza Gradle de nuevo: **File** → **Sync Project with Gradle Files**
4. Si persiste, invalida cachés: **File** → **Invalidate Caches / Restart**

### Problema 2: "No devices found"

**Solución:**
1. Verifica que el emulador está iniciado completamente
2. Verifica en Device Manager que el emulador aparece como "Running"
3. Reinicia el emulador si es necesario
4. Verifica que ADB está funcionando: Abre terminal y ejecuta `adb devices`

### Problema 3: "Installation failed"

**Solución:**
1. Desinstala la aplicación anterior del emulador:
   ```bash
   adb uninstall com.example.edfcatalogo_multiplatform
   ```
2. Limpia el proyecto: **Build** → **Clean Project**
3. Reconstruye el proyecto: **Build** → **Rebuild Project**
4. Vuelve a ejecutar la aplicación

### Problema 4: "Build failed"

**Solución:**
1. Verifica que tienes Java 17 configurado:
   - **File** → **Settings** → **Build, Execution, Deployment** → **Build Tools** → **Gradle**
   - **Gradle JDK:** JDK 17
2. Ejecuta el script de sincronización:
   ```bash
   ./android/sync_gradle_version.sh
   ```
3. Limpia el caché de Gradle:
   ```bash
   cd android
   rm -rf .gradle build
   cd ..
   ```
4. Sincroniza Gradle: **File** → **Sync Project with Gradle Files**

### Problema 5: La aplicación no inicia

**Solución:**
1. Verifica los logs en la pestaña **"Run"** o **"Logcat"**
2. Busca errores específicos
3. Verifica que las variables de entorno se cargan correctamente
4. Verifica que el emulador tiene conexión a internet
5. Reinicia el emulador si es necesario

## 📝 Notas Importantes

### Primera Ejecución
- La primera vez que ejecutes la aplicación puede tardar más tiempo (3-5 minutos)
- Esto es normal debido a la compilación y descarga de dependencias

### Emulador
- El emulador puede tardar 1-2 minutos en iniciarse completamente
- Asegúrate de que el emulador está completamente cargado antes de ejecutar la aplicación

### Hot Reload
- Hot Reload funciona mejor con cambios pequeños en el código
- Para cambios más grandes, usa Hot Restart
- Para cambios en archivos nativos (Android/iOS), necesitas recompilar

### Logs
- Los logs de Flutter aparecen en la pestaña **"Run"**
- Los logs de Android aparecen en la pestaña **"Logcat"**
- Puedes filtrar los logs por tag, package, o nivel

## 🎯 Verificación Rápida

Antes de ejecutar, verifica:

- [ ] El proyecto está abierto en Android Studio
- [ ] Gradle se sincronizó correctamente
- [ ] Un emulador está iniciado y visible en Device Manager
- [ ] El emulador está seleccionado en el dropdown de dispositivos
- [ ] Java 17 está configurado en Gradle settings
- [ ] El script de sincronización se ejecutó (opcional pero recomendado)

## 🚀 Comandos Rápidos

### Desde la Terminal Integrada

```bash
# Sincronizar versiones de Gradle
./android/sync_gradle_version.sh

# Limpiar proyecto
flutter clean

# Obtener dependencias
flutter pub get

# Ejecutar aplicación
flutter run -d android
```

### Atajos de Teclado

- **Ejecutar:** `Shift + F10` (Windows/Linux) o `Control + R` (macOS)
- **Debug:** `Shift + F9` (Windows/Linux) o `Control + D` (macOS)
- **Hot Reload:** `Ctrl + \` (Windows/Linux) o `Cmd + \` (macOS)
- **Hot Restart:** `Ctrl + Shift + \` (Windows/Linux) o `Cmd + Shift + \` (macOS)
- **Stop:** `Ctrl + F2` (Windows/Linux) o `Cmd + F2` (macOS)

## ✅ Checklist Final

- [ ] Proyecto abierto en Android Studio
- [ ] Gradle sincronizado sin errores
- [ ] Emulador iniciado y visible
- [ ] Aplicación ejecutándose en el emulador
- [ ] Logs muestran que las variables de entorno se cargaron
- [ ] La aplicación muestra la pantalla de inicio/login

---

**¿Necesitas ayuda?** Revisa:
- `INSTRUCCIONES_EJECUTAR_ANDROID.md` - Instrucciones generales
- `GUIA_PRUEBAS_ANDROID.md` - Checklist de pruebas
- `SOLUCION_GRADLE_ANDROID.md` - Solución de problemas de Gradle

**Última actualización:** Noviembre 2024

