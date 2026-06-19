# 🔧 Solución: Error de Gradle en Android

## ❌ Problema

```
A problem occurred configuring root project 'flutter_plugin_android_lifecycle'.
Failed to apply plugin 'com.android.internal.version-check'. 
Minimum supported Gradle version is 8.13. Current version is 8.10.
```

## ✅ Solución Implementada

### 1. **Actualizar Gradle a 8.13**

El archivo `android/gradle/wrapper/gradle-wrapper.properties` está configurado para usar Gradle 8.13:

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip
```

### 2. **Actualizar Android Gradle Plugin a 8.7.0**

El archivo `android/settings.gradle.kts` está configurado para usar Android Gradle Plugin 8.7.0:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}
```

### 3. **Actualizar Java y Kotlin a versión 17**

El archivo `android/app/build.gradle.kts` está configurado para usar Java 17 y Kotlin JVM target 17:

```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
}
```

### 4. **Configurar gradle.properties**

Se ha creado/actualizado `android/gradle.properties` con configuraciones optimizadas:

```properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
org.gradle.configuration-cache=true
kotlin.jvm.target.validation.mode=warning
```

### 3. **Sincronizar Versión del Plugin**

El plugin `flutter_plugin_android_lifecycle` tiene su propio `build.gradle` que especifica Android Gradle Plugin 8.12.1, pero necesita usar la misma versión que el proyecto (8.7.0).

**Script de sincronización:** `android/sync_gradle_version.sh`

Este script actualiza automáticamente el Android Gradle Plugin en el plugin `flutter_plugin_android_lifecycle` para que use la misma versión que el proyecto.

### 4. **Ejecutar el Script después de `flutter pub get`**

Después de ejecutar `flutter pub get`, ejecuta el script de sincronización:

```bash
./android/sync_gradle_version.sh
```

O puedes agregarlo a un script de post-installación.

## 📋 Configuración Final

- **Gradle:** 8.13
- **Android Gradle Plugin:** 8.7.0
- **Kotlin:** 2.0.21
- **Java:** 17
- **Flutter:** 3.35.7

## 🔄 Proceso Completo

```bash
# 1. Limpiar el proyecto
flutter clean

# 2. Obtener dependencias
flutter pub get

# 3. Sincronizar versiones de Gradle en plugins
./android/sync_gradle_version.sh

# 4. Limpiar caché de Gradle y build
cd android && rm -rf .gradle build && cd ..

# 5. Construir la aplicación
flutter build apk --debug
```

## 🔧 Cambios Adicionales Implementados

### Java y Kotlin actualizados a versión 17
- AGP 8.7.0 requiere Java 17
- Kotlin JVM target actualizado a 17
- Compatibilidad mejorada con las últimas versiones de Android

### gradle.properties optimizado
- Configuración de memoria aumentada a 2048m
- Cache de configuración habilitado
- Validación de Kotlin JVM target en modo warning

## ⚠️ Notas Importantes

1. **El script modifica archivos en `.pub-cache`**: Esto significa que los cambios se perderán cuando ejecutes `flutter pub get` de nuevo. Por eso es importante ejecutar el script después de cada `flutter pub get`.

2. **Solución permanente**: Para una solución más permanente, considera:
   - Crear un hook de Git que ejecute el script después de `flutter pub get`
   - O crear un script wrapper que ejecute ambos comandos

3. **Alternativa**: Si el problema persiste, considera actualizar Flutter a una versión más reciente que sea compatible con Android Gradle Plugin 8.7.0+ y Gradle 8.13.

## 🐛 Si el Error Persiste

Si después de aplicar esta solución el error persiste:

1. Verifica que el script se ejecutó correctamente:
   ```bash
   cat ~/.pub-cache/hosted/pub.dev/flutter_plugin_android_lifecycle-2.0.32/android/build.gradle | grep "classpath"
   ```
   Debe mostrar: `classpath 'com.android.tools.build:gradle:8.7.0'`

2. Limpia completamente el proyecto:
   ```bash
   flutter clean
   cd android && rm -rf .gradle build && cd ..
   rm -rf ~/.gradle/caches
   ```

3. Reconstruye el proyecto:
   ```bash
   flutter pub get
   ./android/sync_gradle_version.sh
   flutter build apk --debug
   ```

## 📚 Referencias

- [Android Gradle Plugin Compatibility](https://developer.android.com/build/releases/gradle-plugin#updating-gradle)
- [Gradle Compatibility Matrix](https://docs.gradle.org/current/userguide/compatibility.html)

---

**Última actualización:** Enero 2025  
**Versión de Flutter:** 3.35.7  
**Versión de Gradle:** 8.13  
**Versión de Android Gradle Plugin:** 8.7.0

