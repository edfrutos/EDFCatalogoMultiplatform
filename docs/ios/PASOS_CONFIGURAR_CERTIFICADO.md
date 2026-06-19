# 🔐 Pasos para Configurar Certificado iOS - GUÍA PASO A PASO

## ✅ Paso 1: Abrir Xcode (YA HECHO)
Xcode debería estar abierto con el proyecto `Runner.xcworkspace`

---

## 📋 Paso 2: Seleccionar el Proyecto Runner

1. En el **navegador izquierdo** de Xcode, busca y haz clic en el icono azul **"Runner"** (el proyecto, no el target)
2. Debería expandirse mostrando:
   - 📁 Runner (carpeta amarilla)
   - 📁 RunnerTests (carpeta amarilla)
   - 📁 Products (carpeta azul)

---

## 🎯 Paso 3: Seleccionar el Target Runner

1. Con el proyecto **Runner** seleccionado, en el **panel central** verás:
   - **TARGETS** (en la parte superior)
   - **Runner** (debería estar seleccionado por defecto)
   
2. Si no está seleccionado, haz clic en **"Runner"** bajo TARGETS

---

## 🔐 Paso 4: Ir a Signing & Capabilities

1. En la parte **superior del panel central**, verás varias pestañas:
   - General
   - Signing & Capabilities ← **Haz clic aquí**
   - Build Settings
   - Build Phases
   - Build Rules
   - Info

2. Haz clic en **"Signing & Capabilities"**

---

## 👤 Paso 5: Configurar el Signing

En la sección **"Signing"** (arriba del panel):

1. ✅ **Marca la casilla** "Automatically manage signing"
   - Esto permitirá que Xcode gestione automáticamente los certificados

2. En **"Team"**, verás un dropdown:
   - Si ya tienes una cuenta configurada, aparecerá tu nombre/Apple ID
   - Si no, dirá "Add an Account..." o "None"

3. **Haz clic en el dropdown de "Team"**

---

## ➕ Paso 6: Agregar tu Apple ID (si no está)

Si el dropdown dice "Add an Account..." o "None":

1. Haz clic en **"Add an Account..."** o **"Add Account..."**
2. Se abrirá una ventana de login
3. Ingresa tu **Apple ID** y **contraseña**
4. Haz clic en **"Sign In"**
5. Si tienes autenticación de dos factores, completa el proceso
6. Una vez autenticado, cierra la ventana

---

## ✅ Paso 7: Seleccionar tu Team

1. Vuelve al dropdown de **"Team"**
2. Ahora deberías ver tu Apple ID o nombre
3. **Selecciona tu cuenta** del dropdown

---

## 📦 Paso 8: Verificar Bundle Identifier

Justo debajo de "Team", verás **"Bundle Identifier"**:

- Debería mostrar: `com.edfcatalogo.edfcatalogomultiplatform`
- Si aparece un **error en rojo** diciendo que ya está en uso:
  - Haz clic en el Bundle Identifier
  - Cambia a algo único, por ejemplo: `com.tunombre.edfcatalogomultiplatform`

---

## ✨ Paso 9: Xcode Creará el Certificado Automáticamente

Una vez que seleccionas tu Team:

1. Xcode automáticamente:
   - ✅ Creará un certificado de desarrollo
   - ✅ Creará un provisioning profile
   - ✅ Registrará tu dispositivo (si está conectado)

2. Verás un mensaje verde: **"Signing certificate is valid"** o similar

3. Si aparece algún error:
   - **"Signing certificate not found"** → Xcode lo creará automáticamente
   - **"Provisioning profile not found"** → Xcode lo creará automáticamente
   - Solo espera unos segundos

---

## 📱 Paso 10: Conectar tu iPhone (Opcional)

Si quieres probar en tu iPhone físico:

1. **Conecta tu iPhone** a la Mac con un cable USB
2. En tu iPhone, si aparece un mensaje **"Trust This Computer?"**:
   - Toca **"Trust"**
   - Ingresa tu código de acceso del iPhone si es necesario

3. En Xcode:
   - En la **barra superior**, verás un dropdown de dispositivos
   - Selecciona tu iPhone de la lista

---

## 🚀 Paso 11: Probar la Configuración

1. En Xcode, presiona **`Cmd + B`** para compilar
2. O presiona **`Cmd + R`** para compilar y ejecutar
3. Si todo está bien configurado:
   - La app se compilará
   - Se instalará en tu dispositivo/simulador
   - Se ejecutará automáticamente

---

## 🔍 Verificar que Funcionó

### En Xcode:
- ✅ "Signing certificate is valid" (mensaje verde)
- ✅ "Provisioning profile is valid" (mensaje verde)
- ✅ No hay errores en rojo

### En tu iPhone (si instalaste ahí):
1. La app se instalará (puede tardar un minuto)
2. La primera vez que la abras, verás un mensaje:
   - **"Untrusted Developer"**
3. Para solucionarlo:
   - Ve a **Settings** → **General** → **VPN & Device Management** (o **Device Management**)
   - Encuentra tu certificado (tu nombre o Apple ID)
   - Toca en él
   - Toca **"Trust [tu nombre]"**
   - Vuelve a abrir la app

---

## ⚠️ Problemas Comunes

### Error: "No signing certificate found"
- **Solución:** Asegúrate de estar logueado en Xcode
- Ve a Xcode → Settings (o Preferences) → Accounts
- Verifica que tu Apple ID esté ahí

### Error: "Bundle identifier is already in use"
- **Solución:** Cambia el Bundle Identifier a algo único
- Por ejemplo: `com.tunombre.edfcatalogomultiplatform`

### Error: "Device not registered"
- **Solución:** Conecta tu iPhone a la Mac
- Abre Xcode → Window → Devices and Simulators
- Tu dispositivo debería aparecer automáticamente

### Error: "Provisioning profile creation failed"
- **Solución:** Espera unos segundos, Xcode suele resolverlo automáticamente
- Si persiste, desmarca y vuelve a marcar "Automatically manage signing"

---

## ✅ Checklist Final

- [ ] Xcode abierto con Runner.xcworkspace
- [ ] Target "Runner" seleccionado
- [ ] Pestaña "Signing & Capabilities" abierta
- [ ] "Automatically manage signing" marcado
- [ ] Team seleccionado (tu Apple ID)
- [ ] Bundle Identifier configurado (sin errores en rojo)
- [ ] Mensaje verde: "Signing certificate is valid"
- [ ] Compilación exitosa (Cmd + B)

---

## 🎯 Siguiente Paso

Una vez configurado el certificado, puedes ejecutar:

```bash
flutter run -d ios
```

O desde Xcode:
- Presiona `Cmd + R` para compilar y ejecutar

