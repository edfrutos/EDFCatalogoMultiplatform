# 📱 Instrucciones: Configuración de Gradle para Android

## ⚠️ Problema Resuelto

El error original indicaba que el plugin `flutter_plugin_android_lifecycle` requería Gradle 8.13, pero había incompatibilidades entre las versiones de Gradle, Android Gradle Plugin, Kotlin y Flutter Tools.

## ✅ Solución Aplicada

### Configuración Final

1. **Gradle 8.13** - Requerido por el plugin
2. **Android Gradle Plugin 8.7.0** - Compatible con Gradle 8.13
3. **Kotlin 2.0.21** - Versión estable compatible
4. **Java 17** - Requerido por AGP 8.7.0
5. **Script de sincronización** - Mantiene consistencia entre proyecto y plugins

## 🚀 Pasos para Compilar

### Opción 1: Compilación Normal

```bash
# 1. Limpiar proyecto
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Sincronizar versiones de Gradle en plugins
./android/sync_gradle_version.sh

# 4. Compilar
flutter build apk --debug
# o
flutter run -d android
```

### Opción 2: Desde Android Studio

1. Abre el proyecto en Android Studio
2. Ejecuta `flutter pub get` desde la terminal integrada
3. Ejecuta `./android/sync_gradle_version.sh`
4. Sincroniza el proyecto con Gradle (File > Sync Project with Gradle Files)
5. Ejecuta la aplicación (Run > Run 'app')

## 🔧 Archivos Modificados

### 1. `android/gradle/wrapper/gradle-wrapper.properties`
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip
```

### 2. `android/settings.gradle.kts`
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}
```

### 3. `android/app/build.gradle.kts`
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
}
```

### 4. `android/gradle.properties` (nuevo)
```properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
org.gradle.configuration-cache=true
kotlin.jvm.target.validation.mode=warning
```

### 5. `android/sync_gradle_version.sh` (nuevo)
Script que sincroniza la versión de Android Gradle Plugin en los plugins de Flutter.

## ⚠️ Importante

### Después de cada `flutter pub get`

**SIEMPRE** ejecuta el script de sincronización:

```bash
./android/sync_gradle_version.sh
```

Esto es necesario porque:
- El plugin `flutter_plugin_android_lifecycle` tiene su propio `build.gradle`
- Este archivo se sobrescribe cuando se ejecuta `flutter pub get`
- El script restaura la versión correcta de AGP (8.7.0)

### Automatización (Opcional)

Puedes crear un alias o script wrapper:

```bash
# Crear alias en ~/.zshrc o ~/.bashrc
alias flutter-get="flutter pub get && ./android/sync_gradle_version.sh"
```

O crear un script `flutter_get_sync.sh`:

```bash
#!/bin/bash
flutter pub get
./android/sync_gradle_version.sh
```

## 🐛 Solución de Problemas

### Error: "Minimum supported Gradle version is 8.13"

**Solución:** Verifica que `gradle-wrapper.properties` tenga Gradle 8.13:
```bash
cat android/gradle/wrapper/gradle-wrapper.properties | grep distributionUrl
```

### Error: "Execution failed for task ':gradle:compileKotlin'"

**Soluciones:**
1. Verifica que Java 17 esté instalado:
   ```bash
   java -version
   ```

2. Verifica que `build.gradle.kts` use Java 17:
   ```bash
   grep -A 2 "sourceCompatibility" android/app/build.gradle.kts
   ```

3. Limpia completamente el proyecto:
   ```bash
   flutter clean
   cd android && rm -rf .gradle build && cd ..
   rm -rf ~/.gradle/caches
   ```

4. Reconstruye:
   ```bash
   flutter pub get
   ./android/sync_gradle_version.sh
   flutter build apk --debug
   ```

### Error: "Plugin requires AGP 8.7.0 but project uses 8.X.X"

**Solución:** Ejecuta el script de sincronización:
```bash
./android/sync_gradle_version.sh
```

Verifica que funcionó:
```bash
cat ~/.pub-cache/hosted/pub.dev/flutter_plugin_android_lifecycle-2.0.32/android/build.gradle | grep "classpath"
```

Debería mostrar: `classpath 'com.android.tools.build:gradle:8.7.0'`

## 📊 Compatibilidad

| Componente | Versión | Notas |
|------------|---------|-------|
| Gradle | 8.13 | Requerido por el plugin |
| Android Gradle Plugin | 8.7.0 | Compatible con Gradle 8.13 |
| Kotlin | 2.0.21 | Versión estable |
| Java | 17 | Requerido por AGP 8.7.0 |
| Flutter | 3.35.7 | Versión estable actual |

## 🔍 Verificación

Para verificar que todo está configurado correctamente:

```bash
# 1. Verificar versión de Gradle
cd android && ./gradlew --version | head -3

# 2. Verificar versión de AGP en settings.gradle.kts
grep "com.android.application" android/settings.gradle.kts

# 3. Verificar versión de AGP en el plugin
cat ~/.pub-cache/hosted/pub.dev/flutter_plugin_android_lifecycle-2.0.32/android/build.gradle | grep "classpath"

# 4. Verificar Java y Kotlin en build.gradle.kts
grep -A 1 "sourceCompatibility\|jvmTarget" android/app/build.gradle.kts
```

## 📝 Notas Finales

1. **El script de sincronización es crítico**: Sin él, los plugins pueden usar versiones incompatibles de AGP.

2. **Java 17 es obligatorio**: AGP 8.7.0 requiere Java 17. Asegúrate de tenerlo instalado.

3. **Limpiar después de cambios**: Siempre limpia el proyecto después de cambiar configuraciones de Gradle.

4. **Verificar compatibilidad**: Antes de actualizar Flutter o dependencias, verifica la compatibilidad con estas versiones.

---

**Última actualización:** Enero 2025  
**Versión de Flutter:** 3.35.7  
**Versión de Gradle:** 8.13  
**Versión de Android Gradle Plugin:** 8.7.0

