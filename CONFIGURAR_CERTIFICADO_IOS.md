# 🔐 Configurar Certificado de Desarrollo iOS

## 📋 Opción 1: Usar Simulador (Sin Certificado)

El simulador **NO requiere certificado**, así que puedes probar la app inmediatamente:

```bash
# Iniciar simulador
open -a Simulator

# Ejecutar app en simulador
flutter run -d ios
```

## 📋 Opción 2: Configurar Certificado para Dispositivo Físico

Si quieres probar en tu iPhone físico, necesitas configurar el certificado:

### Paso 1: Abrir Xcode

```bash
open ios/Runner.xcworkspace
```

### Paso 2: Configurar Signing & Capabilities

1. En Xcode, selecciona el proyecto **Runner** en el navegador izquierdo
2. Selecciona el target **Runner** 
3. Ve a la pestaña **"Signing & Capabilities"**
4. En la sección **"Signing"**:
   - Marca la casilla **"Automatically manage signing"**
   - En **"Team"**, selecciona tu Apple ID o crea un nuevo equipo
   - Si no tienes cuenta, haz clic en **"Add Account..."** e inicia sesión con tu Apple ID

### Paso 3: Verificar Bundle Identifier

- El Bundle Identifier debe ser único
- Actualmente está configurado como: `com.edfcatalogo.edfcatalogomultiplatform`
- Si ya existe, puedes cambiarlo a algo más único como: `com.tudominio.edfcatalogomultiplatform`

### Paso 4: Confiar en el Certificado en el iPhone

Después de instalar la app en tu iPhone por primera vez:

1. Ve a **Settings** (Configuración) en tu iPhone
2. Ve a **General** → **VPN & Device Management** (o **Device Management**)
3. Encuentra tu certificado de desarrollador
4. Toca en él y selecciona **"Trust [tu nombre]"**

### Paso 5: Ejecutar en el Dispositivo

```bash
flutter run -d ios
```

## ⚠️ Limitaciones de Cuenta Gratuita

Con una cuenta de desarrollador **gratuita** (Apple ID personal):

- ✅ Puedes desarrollar y probar en tus propios dispositivos
- ✅ Las apps expiran después de 7 días (necesitas recompilar)
- ✅ Limitado a 3 dispositivos registrados
- ❌ No puedes publicar en el App Store
- ❌ No puedes usar algunas funcionalidades avanzadas (push notifications, etc.)

## 💰 Cuenta de Desarrollador Pagada ($99/año)

Si necesitas:
- Publicar en el App Store
- Apps que no expiran
- Más dispositivos de prueba
- Funcionalidades avanzadas

Puedes suscribirte en: https://developer.apple.com/programs/

## 🔧 Solución de Problemas

### Error: "No signing certificate found"
- Asegúrate de estar logueado en Xcode con tu Apple ID
- Ve a Xcode → Preferences → Accounts → Agrega tu Apple ID

### Error: "Bundle identifier is already in use"
- Cambia el Bundle Identifier en Xcode
- Target Runner → Signing & Capabilities → Bundle Identifier
- Usa algo único como: `com.tunombre.edfcatalogomultiplatform`

### Error: "Device not registered"
- Conecta tu iPhone a la Mac
- Abre Xcode → Window → Devices and Simulators
- Tu dispositivo debería aparecer automáticamente
- Si no, confía en la computadora en tu iPhone

## 📝 Notas

- **Simulador:** No requiere certificado, perfecto para desarrollo
- **Dispositivo físico:** Requiere certificado, pero permite probar funcionalidades reales (cámara, GPS, etc.)
- **Certificado gratuito:** Funciona para desarrollo, pero las apps expiran cada 7 días

