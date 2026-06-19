# 📋 Contexto de Sesión - EDFCatalogoMultiplatform

## 🎯 Estado Actual del Proyecto

**Último commit:** `29348bd` - "feat: Implementación completa de funcionalidades principales"  
**Branch:** `main`  
**Repositorio remoto:** `git@github.com:edfrutos/EDFCatalogoMultiplatform.git`  
**Estado:** Sincronizado con origin/main ✅

---

## ✅ Funcionalidades Implementadas en Esta Sesión

### 1. **Reproducción de Videos de YouTube**
- ✅ Implementada reproducción in-app de videos de YouTube usando `webview_flutter`
- ✅ Control de navegación para evitar redirecciones externas
- ✅ HTML con iframe embebido similar a la aplicación de referencia Swift
- ✅ Solución al problema de ventanas superpuestas

**Archivos modificados:**
- `lib/views/screens/widgets/file_viewer_view.dart`
- `pubspec.yaml` (agregado `webview_flutter: ^4.9.0`)

### 2. **Descarga de Archivos**
- ✅ Implementado botón de descarga en `FileViewerView`
- ✅ Usa `file_picker` para seleccionar ubicación de guardado
- ✅ Muestra progreso y confirmación
- ✅ Bloquea descarga de videos de streaming
- ✅ Manejo de errores completo

**Archivos modificados:**
- `lib/views/screens/widgets/file_viewer_view.dart`

### 3. **Foto de Perfil de Usuario**
- ✅ Selección de imagen usando `file_picker` (mejor para desktop)
- ✅ Visualización de foto de perfil desde URL almacenada
- ✅ Subida a S3 al guardar el perfil
- ✅ Eliminación de foto de perfil
- ✅ Avatar mostrado en botón de perfil en `CatalogsView`
- ✅ Integración completa con MongoDB

**Archivos modificados:**
- `lib/views/screens/profile_view.dart`
- `lib/views/screens/catalogs_view.dart`
- `lib/services/s3_service.dart` (corrección de firma AWS)

### 4. **Diálogo de Edición de Catálogos**
- ✅ Implementado diálogo completo para editar catálogos
- ✅ Integrado con `CatalogViewModel.updateCatalog`
- ✅ Mensajes de éxito/error
- ✅ Actualización en tiempo real

**Archivos modificados:**
- `lib/views/screens/catalogs_view.dart`
- `lib/views/screens/widgets/edit_catalog_dialog.dart`

### 5. **Navegación desde Perfil de Usuario**
- ✅ AppBar con botón "Volver" cuando se accede mediante `Navigator.push`
- ✅ AppBar condicional (no aparece desde `MainView` sidebar)
- ✅ Navegación fluida entre vistas

**Archivos modificados:**
- `lib/views/screens/profile_view.dart`

### 6. **Correcciones de S3 Service**
- ✅ Detección de `S3_BUCKET_NAME` en `.env` (antes solo buscaba `BUCKET_NAME`)
- ✅ Agregado header `x-amz-content-sha256` requerido por AWS Signature V4
- ✅ Agregado header `host` en la firma (requerido por AWS)
- ✅ Validaciones de configuración mejoradas
- ✅ Logs de diagnóstico detallados

**Archivos modificados:**
- `lib/services/s3_service.dart`
- `lib/utils/env_config.dart`

### 7. **Resolución de Conflictos de Nombres**
- ✅ Resuelto conflicto entre `FileType` del modelo y `FileType` de `file_picker`
- ✅ Uso de alias de importación: `import 'package:file_picker/file_picker.dart' as file_picker;`

**Archivos modificados:**
- `lib/views/screens/widgets/file_viewer_view.dart`
- `lib/views/screens/profile_view.dart`

---

## 🔧 Problemas Técnicos Resueltos

### Problema 1: Videos de YouTube abriendo en ventana externa
**Solución:** Implementación de `NavigationDelegate` estricto que bloquea todas las navegaciones del main frame después de la carga inicial, permitiendo solo subframes.

### Problema 2: Header `x-amz-content-sha256` faltante
**Solución:** Agregado cálculo del hash SHA256 del contenido y incluido como header en la petición.

### Problema 3: Header `host` no firmado
**Solución:** Agregado header `host` explícitamente a los headers antes de generar la firma AWS Signature V4.

### Problema 4: `BUCKET_NAME` vacío
**Solución:** Actualizado `EnvConfig` para buscar tanto `S3_BUCKET_NAME` como `BUCKET_NAME` en el archivo `.env`.

### Problema 5: Conflicto de nombres `FileType`
**Solución:** Uso de alias de importación para `file_picker`, permitiendo usar ambos tipos sin conflicto.

---

## 📁 Archivos Principales del Proyecto

### Servicios
- `lib/services/mongo_service.dart` - Conexión y operaciones con MongoDB
- `lib/services/s3_service.dart` - Subida y gestión de archivos en AWS S3
- `lib/services/keychain_service.dart` - Almacenamiento seguro (Keychain macOS)
- `lib/services/sync_service.dart` - Sincronización online/offline
- `lib/services/pagination_service.dart` - Paginación de catálogos
- `lib/services/export_service.dart` - Exportación de datos (CSV, Excel)
- `lib/services/email_service.dart` - Envío de emails (Brevo)
- `lib/services/local_storage_service.dart` - Almacenamiento local

### ViewModels
- `lib/viewmodels/auth_viewmodel.dart` - Gestión de autenticación
- `lib/viewmodels/catalog_viewmodel.dart` - Gestión de catálogos
- `lib/viewmodels/catalog_detail_viewmodel.dart` - Detalle de catálogo
- `lib/viewmodels/admin_viewmodel.dart` - Panel de administración

### Modelos
- `lib/models/user.dart` - Modelo de usuario
- `lib/models/catalog.dart` - Modelo de catálogo y filas
- `lib/models/file_type.dart` - Enum de tipos de archivo
- `lib/models/column_definition.dart` - Definición de columnas

### Vistas Principales
- `lib/views/screens/login_view.dart` - Login de usuarios
- `lib/views/screens/profile_view.dart` - Perfil de usuario (con foto)
- `lib/views/screens/catalogs_view.dart` - Lista de catálogos
- `lib/views/screens/catalog_detail_view.dart` - Detalle de catálogo
- `lib/views/screens/admin_view.dart` - Panel de administración
- `lib/views/screens/main_view.dart` - Vista principal con sidebar

### Widgets
- `lib/views/screens/widgets/file_viewer_view.dart` - Visualizador de archivos (PDF, imágenes, videos, texto, YouTube)
- `lib/views/screens/widgets/add_edit_row_dialog.dart` - Diálogo para agregar/editar filas
- `lib/views/screens/widgets/create_catalog_dialog.dart` - Diálogo para crear catálogos
- `lib/views/screens/widgets/edit_catalog_dialog.dart` - Diálogo para editar catálogos

---

## 🔑 Configuración Importante

### Variables de Entorno (.env)
El archivo `.env` contiene credenciales sensibles y **NO está en el repositorio**:
- `MONGO_URI` - URI de conexión a MongoDB
- `MONGO_DB` - Nombre de la base de datos
- `S3_BUCKET_NAME` o `BUCKET_NAME` - Nombre del bucket S3
- `AWS_ACCESS_KEY_ID` - Clave de acceso AWS
- `AWS_SECRET_ACCESS_KEY` - Clave secreta AWS
- `AWS_REGION` - Región AWS (default: eu-central-1)
- `USE_S3` - Habilitar/deshabilitar S3 (true/false)
- `BREVO_API_KEY` - API key de Brevo para emails

### macOS Entitlements
- `macos/Runner/DebugProfile.entitlements` - Permisos para desarrollo
- `macos/Runner/Release.entitlements` - Permisos para release
- Incluye: `com.apple.security.network.client` y `com.apple.security.network.server`

---

## 🐛 Issues Conocidos y Soluciones

### Issue: Keychain no disponible en desarrollo sin certificado
**Solución:** Implementado fallback a `SharedPreferences` cuando Keychain falla. El usuario tendrá que iniciar sesión cada vez en desarrollo sin certificado.

### Issue: `.env` no encontrado después de `flutter clean`
**Solución:** El archivo `.env` debe copiarse manualmente a `build/macos/Build/Products/Debug/edfcatalogomultiplatform.app/Contents/Resources/.env` después de cada `flutter clean`.

### Issue: Logs excesivos en macOS
**Solución:** Logs silenciosos cuando Keychain/SharedPreferences fallan en desarrollo.

---

## 📝 Tareas Pendientes de la Hoja de Ruta

### Prioridad Alta
- ⏳ Mejorar validación de datos en formularios de edición de filas
- ⏳ Implementar tests para gestión de archivos (subir, ver, descargar, eliminar)
- ⏳ Optimizar rendimiento con lazy loading de imágenes y paginación mejorada

### Prioridad Media
- ⏳ Búsqueda y filtrado avanzado (parcialmente implementado)
- ⏳ Modo offline completo con sincronización
- ⏳ Compartir y colaboración básica

### Prioridad Baja
- ⏳ Internacionalización (i18n)
- ⏳ Accesibilidad completa
- ⏳ Seguridad avanzada (2FA)

---

## 🚀 Cómo Continuar el Trabajo

### Para recuperar el contexto:
1. Lee este archivo `CONTEXTO_SESION.md`
2. Revisa el último commit: `git log -1`
3. Verifica el estado: `git status`

### Comandos útiles:
```bash
# Ver cambios recientes
git log --oneline -10

# Ver estado actual
git status

# Ver diferencias con el último commit
git diff HEAD

# Ejecutar la aplicación
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
flutter run -d macos
```

### Archivos clave para revisar:
- `lib/services/s3_service.dart` - Implementación de S3 (revisar headers de firma AWS)
- `lib/views/screens/profile_view.dart` - Foto de perfil implementada
- `lib/views/screens/widgets/file_viewer_view.dart` - Visualizador de archivos con YouTube
- `lib/utils/env_config.dart` - Configuración de variables de entorno

---

## 📊 Estado de Funcionalidades

### ✅ Completadas
- [x] Autenticación de usuarios
- [x] Gestión de catálogos (CRUD)
- [x] Gestión de filas (CRUD)
- [x] Visualización de archivos (PDF, imágenes, videos, texto, Markdown)
- [x] Reproducción in-app de videos de YouTube
- [x] Subida de archivos a S3
- [x] Descarga de archivos
- [x] Foto de perfil (selección, subida, visualización, eliminación)
- [x] Edición de catálogos
- [x] Panel de administración básico
- [x] Búsqueda básica
- [x] Paginación
- [x] Persistencia de sesión

### ⏳ Pendientes (de la hoja de ruta)
- [ ] Validación avanzada de datos
- [ ] Tests automatizados
- [ ] Lazy loading optimizado
- [ ] Modo offline completo
- [ ] Compartir catálogos
- [ ] Búsqueda avanzada completa

---

## 🔍 Debugging y Troubleshooting

### Si S3 falla al subir:
1. Verificar que `.env` tenga `S3_BUCKET_NAME` configurado
2. Verificar que `USE_S3=true` en `.env`
3. Revisar logs: buscar "📤 Iniciando subida de archivo"
4. Verificar que los headers `x-amz-content-sha256` y `host` estén presentes

### Si la foto de perfil no se muestra:
1. Verificar que la URL esté guardada en MongoDB (`ProfileImageUrl`)
2. Verificar conexión a internet para cargar imagen desde S3
3. Revisar logs del `CachedNetworkImage`

### Si YouTube no reproduce:
1. Verificar logs de navegación en consola
2. Buscar "🚫 BLOQUEADA navegación principal"
3. Verificar que `webview_flutter` esté instalado

---

## 📞 Información de Contacto del Proyecto

- **Repositorio:** git@github.com:edfrutos/EDFCatalogoMultiplatform.git
- **Branch principal:** `main`
- **Última actualización:** 1 de Noviembre de 2025

---

## 💡 Notas Importantes

1. **`.env` no está en el repositorio** - Asegúrate de configurarlo localmente
2. **Certificado de desarrollo** - Para Keychain en macOS, se necesita certificado de desarrollo
3. **Hot restart vs rebuild** - Algunos cambios (entitlements, Info.plist) requieren `flutter clean && flutter run`
4. **YouTube embed** - Usa `youtube-nocookie.com` para mejor privacidad
5. **S3 Signature V4** - Requiere headers específicos (`host`, `x-amz-content-sha256`, `x-amz-date`)

---

**Generado automáticamente:** 1 de Noviembre de 2025  
**Último commit:** `29348bd` - feat: Implementación completa de funcionalidades principales

