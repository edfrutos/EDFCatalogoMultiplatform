# 📱 Guía Paso a Paso: Eliminar Dispositivos de Apple Developer

## 🎯 Objetivo
Ir a la sección donde puedes ver y eliminar tus dispositivos registrados.

## 📋 Pasos Detallados

### Paso 1: Ir a la Sección de Cuenta

En la barra de navegación superior que ves:

1. **Haz clic en "Cuenta"** (en la parte superior derecha de la página)
2. Esto te llevará a la sección de tu cuenta de desarrollador

### Paso 2: Iniciar Sesión (si es necesario)

Si no has iniciado sesión:
1. Te pedirá tu **Apple ID** y **contraseña**
2. Si tienes autenticación de dos factores, completa el proceso
3. Inicia sesión

### Paso 3: Ir a Certificates, Identifiers & Profiles

Una vez en tu cuenta, deberías ver varias opciones. Busca y haz clic en:

**"Certificates, Identifiers & Profiles"** o **"Certificados, identificadores y perfiles"**

### Paso 4: Ir a la Sección de Dispositivos

En el menú lateral izquierdo (o en la página principal), busca y haz clic en:

**"Devices"** o **"Dispositivos"**

### Paso 5: Ver y Eliminar Dispositivos

1. Verás una lista de todos tus dispositivos registrados
2. Busca dispositivos que ya no uses (iPhones antiguos, iPads, etc.)
3. Haz clic en el dispositivo que quieres eliminar
4. Haz clic en **"Remove"** o **"Eliminar"**
5. Confirma la eliminación

## 🔄 Alternativa: Desde Xcode

Si prefieres hacerlo desde Xcode:

1. Abre Xcode
2. Ve a **Xcode** → **Settings** (o **Preferences**) → **Accounts**
3. Selecciona tu Apple ID
4. Haz clic en **"Manage Certificates..."**
5. O ve a **Window** → **Devices and Simulators** → **Devices**
6. Puedes ver tus dispositivos desde ahí

## ⚡ Solución Rápida: Usar Simulador

Si prefieres no eliminar dispositivos, puedes usar el simulador directamente:

```bash
# Ejecutar en simulador (no requiere registro de dispositivo)
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
flutter run -d ios
```

El simulador funciona perfectamente y no tiene límite de dispositivos.

