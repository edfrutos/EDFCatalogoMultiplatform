# 📱 Guía de Pruebas para Android - EDFCatalogoMultiplatform

## ✅ Correcciones Implementadas

### 1. **Permisos en AndroidManifest.xml**
- ✅ `INTERNET` - Para conexiones de red (MongoDB, AWS S3)
- ✅ `ACCESS_NETWORK_STATE` - Para verificar estado de conectividad
- ✅ `READ_EXTERNAL_STORAGE` - Para leer archivos (Android ≤12)
- ✅ `WRITE_EXTERNAL_STORAGE` - Para escribir archivos (Android ≤10)
- ✅ `READ_MEDIA_IMAGES` - Para leer imágenes (Android 13+)
- ✅ `READ_MEDIA_VIDEO` - Para leer videos (Android 13+)
- ✅ `READ_MEDIA_AUDIO` - Para leer audio (Android 13+)
- ✅ `usesCleartextTraffic="true"` - Para permitir HTTP durante desarrollo

### 2. **Carga de Variables de Entorno (.env)**
- ✅ Implementada carga desde assets usando `rootBundle` (mismo método que web)
- ✅ Fallback a búsqueda en sistema de archivos si falla la carga desde assets
- ✅ El archivo `.env` está correctamente incluido en `pubspec.yaml` como asset

### 3. **Configuración de Android**
- ✅ Java 11 configurado correctamente
- ✅ Kotlin configurado correctamente
- ✅ MinSDK, TargetSDK y CompileSDK usando valores de Flutter (recomendado)

---

## 🚀 Pasos para Probar en Android Studio

### 1. **Preparación**

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
flutter pub get
flutter clean
flutter pub get
```

### 2. **Verificar Configuración**

```bash
# Verificar que Flutter detecta Android
flutter doctor

# Verificar que hay emuladores/dispositivos disponibles
flutter devices
```

### 3. **Ejecutar la Aplicación**

```bash
# Opción 1: Desde terminal
flutter run -d android

# Opción 2: Desde Android Studio
# 1. Abre el proyecto en Android Studio
# 2. Selecciona un emulador/dispositivo Android
# 3. Haz clic en "Run" (▶️)
```

---

## 🧪 Checklist de Pruebas

### **Prueba 1: Carga de Variables de Entorno**

- [ ] La aplicación inicia sin errores
- [ ] En los logs aparece: `✅ Variables de entorno cargadas desde assets para Android`
- [ ] Se muestra el número de variables cargadas: `📋 Variables cargadas: X`
- [ ] No aparecen errores sobre `.env` no encontrado

**Cómo verificar:**
```bash
# Ejecutar la app y revisar los logs
flutter run -d android
# Buscar en la consola los mensajes sobre .env
```

### **Prueba 2: Conexión a MongoDB**

- [ ] La aplicación puede conectarse a MongoDB
- [ ] Se puede iniciar sesión con credenciales válidas
- [ ] Los catálogos se cargan correctamente
- [ ] No aparecen errores de conexión

**Cómo verificar:**
1. Inicia la app
2. Intenta iniciar sesión
3. Verifica que los catálogos se cargan

### **Prueba 3: Gestión de Archivos**

#### 3.1 Selección de Archivos
- [ ] Se puede seleccionar una imagen desde la galería
- [ ] Se puede seleccionar un documento (PDF)
- [ ] Se puede seleccionar un video
- [ ] Los permisos se solicitan correctamente (Android 13+)

#### 3.2 Subida de Archivos a S3
- [ ] Los archivos se suben correctamente a S3
- [ ] Se muestra progreso de subida
- [ ] Los archivos aparecen en el catálogo después de subir
- [ ] No aparecen errores de permisos o conexión

#### 3.3 Visualización de Archivos
- [ ] Las imágenes se muestran correctamente
- [ ] Los PDFs se visualizan correctamente
- [ ] Los videos se reproducen correctamente
- [ ] Los videos de YouTube se reproducen en el WebView

#### 3.4 Descarga de Archivos
- [ ] Se puede descargar un archivo
- [ ] Se puede elegir la ubicación de guardado
- [ ] El archivo se guarda correctamente
- [ ] Se muestra confirmación de descarga

### **Prueba 4: Almacenamiento Seguro**

- [ ] Las credenciales se guardan correctamente (Keychain/Keystore)
- [ ] La sesión persiste después de cerrar la app
- [ ] No aparecen errores de almacenamiento seguro

**Cómo verificar:**
1. Inicia sesión
2. Cierra la app completamente
3. Abre la app de nuevo
4. Verifica que la sesión sigue activa

### **Prueba 5: Conectividad**

- [ ] El estado de conexión se detecta correctamente
- [ ] El modo offline se activa cuando no hay conexión
- [ ] Las operaciones offline se guardan localmente
- [ ] La sincronización funciona al reconectar

**Cómo verificar:**
1. Conecta a internet y carga algunos catálogos
2. Desactiva WiFi/datos móviles
3. Verifica que aparece el indicador "Modo offline"
4. Crea/edita un catálogo offline
5. Reactiva la conexión
6. Verifica que se sincroniza correctamente

### **Prueba 6: Permisos en Tiempo de Ejecución**

#### Android 13+ (API 33+)
- [ ] Se solicitan permisos para leer imágenes
- [ ] Se solicitan permisos para leer videos
- [ ] Se solicitan permisos para leer audio
- [ ] Los permisos se pueden denegar/aceptar correctamente

#### Android 10-12 (API 29-32)
- [ ] Se solicitan permisos de almacenamiento
- [ ] Los permisos se pueden denegar/aceptar correctamente

**Nota:** Los plugins `file_picker` e `image_picker` manejan automáticamente los permisos en tiempo de ejecución.

### **Prueba 7: Rendimiento**

- [ ] La aplicación inicia en menos de 5 segundos
- [ ] Las imágenes se cargan rápidamente
- [ ] No hay lag al navegar entre pantallas
- [ ] Los videos se reproducen sin problemas

### **Prueba 8: Orientación de Pantalla**

- [ ] La aplicación funciona en modo vertical
- [ ] La aplicación funciona en modo horizontal
- [ ] Los elementos se ajustan correctamente al cambiar orientación
- [ ] Los videos se reproducen correctamente en ambas orientaciones

---

## 🐛 Problemas Conocidos y Soluciones

### Problema 1: `.env` no se carga

**Síntomas:**
- Aparece error: `⚠️ No se pudo cargar .env desde assets en Android`
- Las variables de entorno están vacías

**Soluciones:**
1. Verifica que el archivo `.env` existe en la raíz del proyecto
2. Verifica que el archivo `.env` está incluido en `pubspec.yaml`:
   ```yaml
   assets:
     - .env
   ```
3. Ejecuta `flutter clean` y luego `flutter pub get`
4. Reconstruye la aplicación: `flutter run -d android`

### Problema 2: Permisos no se solicitan

**Síntomas:**
- No se pueden seleccionar archivos
- Aparecen errores de permisos

**Soluciones:**
1. Verifica que los permisos están en `AndroidManifest.xml`
2. En Android 13+, los permisos de medios se solicitan automáticamente por `file_picker`
3. Verifica que la app tiene permisos en Configuración > Apps > EDFCatalogoMultiplatform > Permisos

### Problema 3: No se puede conectar a MongoDB

**Síntomas:**
- Error de conexión a MongoDB
- Los catálogos no se cargan

**Soluciones:**
1. Verifica que `MONGO_URI` está correctamente configurado en `.env`
2. Verifica que el dispositivo/emulador tiene conexión a internet
3. Verifica que `usesCleartextTraffic="true"` está en `AndroidManifest.xml` (si usas HTTP)
4. Para producción, usa HTTPS y elimina `usesCleartextTraffic`

### Problema 4: Archivos no se suben a S3

**Síntomas:**
- Los archivos no se suben
- Aparecen errores de AWS

**Soluciones:**
1. Verifica que las credenciales de AWS están en `.env`:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `S3_BUCKET_NAME` o `BUCKET_NAME`
   - `AWS_REGION`
2. Verifica que `USE_S3=true` en `.env`
3. Verifica la conectividad a internet

### Problema 5: WebView de YouTube no funciona

**Síntomas:**
- Los videos de YouTube no se reproducen
- El WebView muestra error

**Soluciones:**
1. Verifica que `webview_flutter` está instalado
2. Verifica que `webview_flutter_android` está instalado
3. Verifica la conectividad a internet
4. Revisa los logs para errores específicos del WebView

---

## 📊 Verificación de Logs

### Logs Esperados al Iniciar

```
✅ Variables de entorno cargadas desde assets para Android
📋 Variables cargadas: X
✅ Variables cargadas: MONGO_URI ✅ Cargada
✅ Variables cargadas: MONGO_DB ✅ Cargada
```

### Logs de Errores Comunes

```
⚠️ No se pudo cargar .env desde assets en Android
⚠️ Error al cargar .env desde assets en Android: [error]
❌ Error de conexión a MongoDB
❌ Error subiendo archivo a S3
```

---

## 🔧 Comandos Útiles

### Ver Logs en Tiempo Real

```bash
# Ver logs de Flutter
flutter run -d android

# Ver logs de Android (adb)
adb logcat | grep -i "edfcatalogo"

# Ver logs específicos de la app
adb logcat | grep -i "flutter"
```

### Limpiar y Reconstruir

```bash
# Limpiar build
flutter clean

# Obtener dependencias
flutter pub get

# Reconstruir
flutter run -d android
```

### Verificar Dispositivos

```bash
# Listar dispositivos disponibles
flutter devices

# Ver dispositivos Android conectados
adb devices
```

---

## 📝 Notas Importantes

### Para Desarrollo
- ✅ `usesCleartextTraffic="true"` permite HTTP (útil para desarrollo)
- ✅ Los permisos se solicitan automáticamente por los plugins
- ✅ El `.env` se carga desde assets (incluido en el APK)

### Para Producción
- ⚠️ Eliminar `usesCleartextTraffic="true"` o configurarlo como `false`
- ⚠️ Usar solo HTTPS para conexiones
- ⚠️ No incluir credenciales sensibles en el `.env` del repositorio
- ⚠️ Usar variables de entorno del sistema o servicios de configuración

### Versiones de Android Soportadas
- **Mínimo:** Android 5.0 (API 21) - Definido por Flutter
- **Recomendado:** Android 8.0+ (API 26+)
- **Probado:** Android 13+ (API 33+) con permisos granulares de medios

---

## ✅ Checklist Final

Antes de considerar las pruebas completas, verifica:

- [ ] La aplicación inicia sin errores
- [ ] Las variables de entorno se cargan correctamente
- [ ] La conexión a MongoDB funciona
- [ ] Los archivos se pueden subir a S3
- [ ] Los archivos se pueden visualizar correctamente
- [ ] Los permisos se solicitan correctamente
- [ ] El modo offline funciona
- [ ] La sincronización funciona
- [ ] El almacenamiento seguro funciona
- [ ] No hay errores críticos en los logs

---

## 📞 Siguiente Paso

Una vez completadas las pruebas, puedes:
1. Continuar con correcciones si encuentras problemas
2. Probar en dispositivos físicos Android
3. Preparar para producción (firmar APK, configurar Google Play, etc.)

---

**Última actualización:** Enero 2025  
**Versión de Flutter:** 3.35.7  
**Versión de Android SDK:** 36.1.0

