# 📝 Comandos para Ejecutar Scripts

## 🎯 Ubicación de los Scripts

Los scripts están ubicados en diferentes directorios del proyecto:

### Scripts en `android/`
- `android/sync_gradle_version.sh` - Sincroniza versiones de Gradle
- `android/build.gradle.kts` - Configuración de build (no es un script ejecutable)

### Scripts en la raíz del proyecto
- `build_android.sh` - Compila la aplicación Android
- `INSTALAR_APK_ANDROID.sh` - Instala el APK en dispositivos

---

## 🚀 Cómo Ejecutar los Scripts

### Opción 1: Desde la Raíz del Proyecto (Recomendado)

```bash
# Navegar a la raíz del proyecto
cd /ruta/a/tu/proyecto/EDFCatalogoMultiplatform

# Ejecutar script de sincronización
./android/sync_gradle_version.sh

# Ejecutar script de compilación
./build_android.sh

# Ejecutar script de instalación
./INSTALAR_APK_ANDROID.sh
```

### Opción 2: Desde el Directorio `android/`

```bash
# Navegar al directorio android
cd /ruta/a/tu/proyecto/EDFCatalogoMultiplatform/android

# Ejecutar script (sin el prefijo android/)
./sync_gradle_version.sh
```

### Opción 3: Usando Ruta Absoluta

```bash
# Desde cualquier directorio
/ruta/a/tu/proyecto/EDFCatalogoMultiplatform/android/sync_gradle_version.sh
```

---

## 📋 Comandos Comunes

### Sincronizar Versiones de Gradle

```bash
# Desde la raíz del proyecto
cd /ruta/a/tu/proyecto/EDFCatalogoMultiplatform
./android/sync_gradle_version.sh
```

### Compilar la Aplicación

```bash
# Desde la raíz del proyecto
cd /ruta/a/tu/proyecto/EDFCatalogoMultiplatform
./build_android.sh
```

### Instalar el APK

```bash
# Desde la raíz del proyecto
cd /ruta/a/tu/proyecto/EDFCatalogoMultiplatform
./INSTALAR_APK_ANDROID.sh
```

---

## ⚠️ Solución de Problemas

### Error: "no such file or directory"

**Problema:** Estás en el directorio incorrecto o usando el path incorrecto.

**Solución:**
1. Verifica en qué directorio estás:
   ```bash
   pwd
   ```

2. Si estás en `android/`, usa:
   ```bash
   ./sync_gradle_version.sh
   ```

3. Si estás en la raíz del proyecto, usa:
   ```bash
   ./android/sync_gradle_version.sh
   ```

### Error: "Permission denied"

**Problema:** El script no tiene permisos de ejecución.

**Solución:**
```bash
# Dar permisos de ejecución
chmod +x android/sync_gradle_version.sh

# Luego ejecutar
./android/sync_gradle_version.sh
```

### Error: "command not found"

**Problema:** El script no existe en la ubicación esperada.

**Solución:**
1. Verifica que el script existe:
   ```bash
   ls -la android/sync_gradle_version.sh
   ```

2. Si no existe, verifica la estructura del proyecto:
   ```bash
   find . -name "sync_gradle_version.sh"
   ```

---

## 🎯 Comandos Rápidos desde Android Studio

### Terminal Integrada en Android Studio

1. **Abrir Terminal Integrada**
   - **View** → **Tool Windows** → **Terminal**
   - O presiona: `Alt + F12` (Windows/Linux) o `Option + F12` (macOS)

2. **Ejecutar Scripts**
   ```bash
   # Desde la raíz del proyecto (por defecto)
   ./android/sync_gradle_version.sh
   ./build_android.sh
   ./INSTALAR_APK_ANDROID.sh
   ```

---

## 📝 Notas Importantes

### Directorio de Trabajo

- **Recomendado:** Siempre trabajar desde la **raíz del proyecto**
- Esto evita confusiones con paths relativos
- Los scripts están diseñados para ejecutarse desde la raíz

### Permisos

- Los scripts deben tener permisos de ejecución (`chmod +x`)
- Si obtienes "Permission denied", ejecuta `chmod +x` en el script

### Paths Relativos vs Absolutos

- **Paths relativos:** `./android/sync_gradle_version.sh` (desde la raíz)
- **Paths absolutos:** `/ruta/a/tu/proyecto/EDFCatalogoMultiplatform/android/sync_gradle_version.sh` (desde cualquier lugar)

---

## 🔧 Verificación Rápida

### Verificar que Estás en el Directorio Correcto

```bash
# Deberías ver algo como:
# /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
pwd
```

### Verificar que el Script Existe

```bash
# Desde la raíz del proyecto
ls -la android/sync_gradle_version.sh

# Deberías ver:
# -rwxr-xr-x  1 usuario  staff  ... android/sync_gradle_version.sh
```

### Verificar Permisos

```bash
# El script debe tener permisos de ejecución (x)
ls -la android/sync_gradle_version.sh

# Si no tiene permisos, ejecuta:
chmod +x android/sync_gradle_version.sh
```

---

## ✅ Checklist

Antes de ejecutar un script, verifica:

- [ ] Estás en el directorio correcto (raíz del proyecto o `android/`)
- [ ] El script existe en la ubicación esperada
- [ ] El script tiene permisos de ejecución
- [ ] Estás usando el path correcto (relativo o absoluto)

---

## 📚 Referencias

- **`COMO_EJECUTAR_ANDROID_STUDIO.md`** - Guía completa de Android Studio
- **`GUIA_RAPIDA_ANDROID_STUDIO.md`** - Guía rápida de referencia
- **`SOLUCION_GRADLE_ANDROID.md`** - Solución de problemas de Gradle

---

**Última actualización:** Noviembre 2024

