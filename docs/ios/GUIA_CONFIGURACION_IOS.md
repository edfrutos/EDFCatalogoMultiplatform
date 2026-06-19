# 📱 Guía de Configuración iOS

## ✅ Pasos Completados

1. ✅ Entitlements creados (`ios/Runner/Runner.entitlements`)
2. ✅ Script de copia de .env creado (`ios/copy_env.sh`)
3. ✅ Info.plist configurado con permisos
4. ✅ Proyecto Xcode configurado con build phase
5. ✅ main.dart actualizado para soportar iOS

## 🚀 Próximos Pasos

### Paso 1: Instalar Dependencias de CocoaPods

```bash
cd ios
pod install
cd ..
```

**Nota:** Si no tienes CocoaPods instalado:
```bash
sudo gem install cocoapods
```

### Paso 2: Verificar que el .env existe

Asegúrate de que el archivo `.env` esté en la raíz del proyecto:
```bash
ls -la .env
```

Si no existe, créalo basándote en `.env.example` o copia el que usas para macOS.

### Paso 3: Abrir el proyecto en Xcode (Opcional pero recomendado)

```bash
open ios/Runner.xcworkspace
```

**IMPORTANTE:** Abre el `.xcworkspace`, NO el `.xcodeproj`

En Xcode, verifica:
1. **Target Runner** → **Build Phases** → Debe aparecer "Copy .env to Bundle"
2. **Target Runner** → **Build Settings** → Buscar "Code Signing Entitlements" → Debe ser `Runner/Runner.entitlements`
3. **Target Runner** → **Signing & Capabilities** → Verificar que el Bundle Identifier esté configurado

### Paso 4: Compilar y Ejecutar

#### Opción A: Desde la terminal (Flutter)
```bash
# Listar dispositivos disponibles
flutter devices

# Ejecutar en simulador iOS
flutter run -d ios

# O especificar un dispositivo específico
flutter run -d "iPhone 15 Pro"
```

#### Opción B: Desde Xcode
1. Selecciona un simulador o dispositivo en la barra superior
2. Presiona `Cmd + R` o haz clic en el botón "Run"

### Paso 5: Verificar que el .env se copió correctamente

Durante el build, deberías ver en los logs:
```
📦 [Build] Copiando .env al bundle de iOS...
✅ Archivo .env copiado a [ruta]
```

Si no ves estos mensajes, verifica:
- Que el script `copy_env.sh` tenga permisos de ejecución: `chmod +x ios/copy_env.sh`
- Que el build phase esté configurado correctamente en Xcode

### Paso 6: Probar la Aplicación

Una vez que la app esté corriendo:

1. **Verificar carga de .env:**
   - Busca en los logs: `✅ Variables cargadas con dotenv desde bundle`
   - Si no aparece, verifica que el .env esté en la ubicación correcta

2. **Probar permisos:**
   - Intentar subir una imagen (debe pedir permiso de fotos)
   - Intentar usar la cámara (debe pedir permiso de cámara)

3. **Probar funcionalidades principales:**
   - Login/Registro
   - Crear/editar catálogos
   - Subir archivos a S3
   - Backups a Google Drive

## 🔧 Solución de Problemas

### Error: "CocoaPods not installed"
```bash
sudo gem install cocoapods
pod setup
```

### Error: "No such module 'Flutter'"
```bash
cd ios
pod install
cd ..
flutter clean
flutter pub get
```

### Error: "Signing for Runner requires a development team"
- Abre Xcode → Runner target → Signing & Capabilities
- Selecciona tu equipo de desarrollo
- O configura un certificado de desarrollo

### Error: ".env no encontrado"
- Verifica que el archivo `.env` esté en la raíz del proyecto
- Verifica que el script `copy_env.sh` tenga permisos: `chmod +x ios/copy_env.sh`
- Revisa los logs del build en Xcode para ver dónde está buscando el archivo

### El .env no se está copiando
1. Abre Xcode → Runner target → Build Phases
2. Verifica que "Copy .env to Bundle" esté presente
3. Verifica que el script apunte a: `"$PROJECT_DIR/../ios/copy_env.sh"`
4. Ejecuta el build y revisa los logs del script

## 📝 Notas Importantes

- **Bundle Identifier:** Asegúrate de que sea único. Actualmente es: `com.edfcatalogo.edfcatalogomultiplatform`
- **iOS Deployment Target:** Configurado para iOS 13.0+
- **Entitlements:** Incluyen keychain-access-groups para `flutter_secure_storage`
- **Permisos:** Todos los permisos necesarios están en Info.plist con descripciones en español

## ✅ Checklist Final

- [ ] CocoaPods instalado y `pod install` ejecutado
- [ ] Archivo `.env` presente en la raíz del proyecto
- [ ] Proyecto Xcode abre correctamente (`.xcworkspace`)
- [ ] Build phase "Copy .env to Bundle" presente
- [ ] Entitlements configurados correctamente
- [ ] App compila sin errores
- [ ] App se ejecuta en simulador/dispositivo
- [ ] Logs muestran que .env se carga correctamente
- [ ] Permisos funcionan (cámara, fotos, etc.)
- [ ] Funcionalidades principales probadas

## 🎯 Siguiente Plataforma

Una vez que iOS esté funcionando correctamente, podemos continuar con:
- **Android** (ya configurado parcialmente)
- **Windows**
- **Linux**

