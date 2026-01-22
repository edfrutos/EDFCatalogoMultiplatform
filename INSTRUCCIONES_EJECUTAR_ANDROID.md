# 📱 Instrucciones para Ejecutar la Aplicación Android

## ✅ Estado Actual

La compilación de Android fue **exitosa**. El APK se generó correctamente en:
- `build/app/outputs/flutter-apk/app-debug.apk` (160 MB)

## 🚀 Opciones para Ejecutar la Aplicación

### Opción 1: Desde Android Studio (Recomendado)

1. **Abrir el proyecto en Android Studio**
   ```bash
   cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
   # Abre Android Studio y selecciona "Open" → selecciona este directorio
   ```

2. **Iniciar un emulador**
   - En Android Studio: **Tools** → **Device Manager**
   - Selecciona un emulador (ej: Pixel_3a_API_36)
   - Haz clic en el botón ▶️ para iniciarlo
   - Espera a que el emulador termine de cargar (puede tardar 1-2 minutos)

3. **Ejecutar la aplicación**
   - Selecciona el emulador en el dropdown superior
   - Haz clic en el botón **Run** (▶️) o presiona `Shift + F10`
   - La aplicación se compilará e instalará automáticamente

### Opción 2: Desde la Terminal con Flutter

1. **Verificar que hay un dispositivo disponible**
   ```bash
   flutter devices
   ```

2. **Iniciar un emulador (si no hay ninguno)**
   ```bash
   # Listar emuladores disponibles
   flutter emulators
   
   # Iniciar un emulador específico
   flutter emulators --launch Pixel_3a_API_36
   ```

3. **Esperar a que el emulador esté listo** (puede tardar 1-2 minutos)

4. **Ejecutar la aplicación**
   ```bash
   cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
   flutter run -d android
   ```

### Opción 3: Instalar APK Manualmente

Si ya tienes el APK compilado y un dispositivo/emulador disponible:

1. **Verificar que hay un dispositivo disponible**
   ```bash
   adb devices
   ```

2. **Instalar el APK**
   ```bash
   cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
   ./INSTALAR_APK_ANDROID.sh
   ```

   O manualmente:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

3. **Ejecutar la aplicación**
   ```bash
   # Desde el dispositivo/emulador, busca la aplicación y ábrela
   # O desde la terminal:
   adb shell am start -n com.example.edfcatalogo_multiplatform/.MainActivity
   ```

## 🔧 Configuración Actual

### Versiones Configuradas
- **Gradle:** 8.13
- **Android Gradle Plugin (AGP):** 8.7.3
- **Kotlin:** 2.1.0
- **Java:** 17
- **MinSDK:** Configurado por Flutter (por defecto)
- **TargetSDK:** Configurado por Flutter (por defecto)

### Archivos de Configuración
- `android/settings.gradle.kts` - Configuración de plugins
- `android/app/build.gradle.kts` - Configuración de la aplicación
- `android/gradle/wrapper/gradle-wrapper.properties` - Versión de Gradle
- `android/gradle.properties` - Propiedades de Gradle
- `android/sync_gradle_version.sh` - Script para sincronizar versiones

## ⚠️ Solución de Problemas

### Problema: "No devices found"
**Solución:**
1. Verifica que el emulador está iniciado completamente (pantalla de Android visible)
2. Ejecuta `adb devices` para verificar que el dispositivo aparece
3. Si no aparece, reinicia el emulador o ejecuta `adb kill-server && adb start-server`

### Problema: "Waiting for device"
**Solución:**
1. Espera a que el emulador termine de cargar (puede tardar 1-2 minutos)
2. Verifica que el emulador no está bloqueado (desbloquea la pantalla)
3. Reinicia el emulador si es necesario

### Problema: "Installation failed"
**Solución:**
1. Desinstala la aplicación anterior: `adb uninstall com.example.edfcatalogo_multiplatform`
2. Limpia el proyecto: `flutter clean`
3. Vuelve a compilar: `./build_android.sh`
4. Instala nuevamente: `./INSTALAR_APK_ANDROID.sh`

### Problema: "Gradle sync failed"
**Solución:**
1. Ejecuta el script de sincronización: `./android/sync_gradle_version.sh`
2. Limpia el caché de Gradle: `cd android && rm -rf .gradle build`
3. En Android Studio: **File** → **Invalidate Caches / Restart**

## 📝 Notas Importantes

1. **Primera ejecución:** La primera vez que ejecutes la aplicación puede tardar más tiempo debido a la compilación y descarga de dependencias.

2. **Hot Reload:** Una vez que la aplicación esté ejecutándose, puedes usar Hot Reload presionando `r` en la terminal o el botón correspondiente en Android Studio.

3. **Logs:** Los logs de la aplicación aparecerán en la consola de Android Studio o en la terminal donde ejecutaste `flutter run`.

4. **Variables de entorno:** La aplicación carga las variables de entorno desde el archivo `.env` que está incluido en los assets de Flutter.

## 🎯 Próximos Pasos

Una vez que la aplicación esté ejecutándose:

1. **Verificar carga de variables de entorno**
   - Revisa los logs para confirmar que se cargaron correctamente
   - Deberías ver: `✅ Variables de entorno cargadas desde assets para Android`

2. **Probar funcionalidades**
   - Consulta `GUIA_PRUEBAS_ANDROID.md` para ver el checklist completo de pruebas
   - Verifica que la aplicación se conecta correctamente a MongoDB
   - Prueba la funcionalidad de descarga de archivos desde S3

3. **Optimizar rendimiento**
   - Monitorea el rendimiento de la aplicación
   - Revisa los logs para detectar errores o advertencias

