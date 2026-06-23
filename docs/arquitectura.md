# Arquitectura — EDFCatalogoMultiplatform

Documento de referencia de la arquitectura técnica del proyecto. Describe capas,
flujos de datos, decisiones de diseño y cómo se relacionan los módulos entre sí.

---

## 1. Visión general

EDFCatalogoMultiplatform es una aplicación Flutter que permite gestionar catálogos
de tablas con soporte multimedia. Corre en seis plataformas desde un único codebase:
**macOS, iOS, Android, Web, Linux y Windows**.

```
┌────────────────────────────────────────────┐
│               Flutter App                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Views   │  │ViewModels│  │ Services │ │
│  │(screens) │←─│(state)   │←─│(data)    │ │
│  └──────────┘  └──────────┘  └──────────┘ │
│                                            │
│  ┌──────────┐  ┌──────────┐               │
│  │  Models  │  │  Utils   │               │
│  └──────────┘  └──────────┘               │
└────────────────────────────────────────────┘
         │           │              │
    MongoDB Atlas  AWS S3     Google Drive
```

---

## 2. Estructura de carpetas

```
lib/
├── main.dart                  # Punto de entrada — llama a initEnv() y runApp()
├── models/                    # Entidades de dominio (User, Catalog, Row, …)
├── services/                  # Acceso a datos externos
│   ├── mongo_service.dart     # Todas las operaciones MongoDB
│   ├── s3_service.dart        # Upload/download en AWS S3
│   ├── keychain_service.dart  # Persistencia segura de sesión
│   └── export_service.dart    # Exportación (PDF, CSV, Excel, compartir)
├── viewmodels/                # Lógica de presentación (ChangeNotifier)
│   └── auth_viewmodel.dart    # Estado de autenticación
├── views/
│   ├── screens/               # Pantallas completas
│   │   ├── admin_*/           # Pantallas de administración
│   │   └── widgets/           # Widgets reutilizables entre pantallas
│   └── …
└── utils/
    ├── env_loader.dart        # Carga de .env multiplataforma + globalEnvMap
    └── env_config.dart        # Getters tipados sobre las variables de entorno
```

---

## 3. Capa de datos

### 3.1 MongoDB (`mongo_service.dart`)

Punto único de acceso a la base de datos. Todas las queries pasan por esta clase.

| Método principal | Descripción |
|-----------------|-------------|
| `authenticateUser()` | Login por email o nombre de usuario |
| `getCatalogs(userId, isAdmin, userEmail)` | Lista de catálogos del usuario |
| `saveCatalog()` / `deleteCatalog()` | CRUD de catálogos |
| `getUsers()` / `updateUser()` | Gestión de usuarios (admin) |

La URI de conexión se construye en `initEnv()` a partir de `MONGO_URI` y `MONGO_DB`.
Para producción se usa MongoDB Atlas; el formato esperado es:
```
mongodb+srv://<user>:<pass>@<cluster>/<db>?retryWrites=true&w=majority
```

### 3.2 AWS S3 (`s3_service.dart`)

Almacenamiento de archivos multimedia (imágenes, vídeos, documentos adjuntos a filas).
Se activa únicamente cuando `USE_S3=true` en `.env`. Si está desactivado, los archivos
se guardan en local o no se adjuntan.

Credenciales necesarias: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
`S3_BUCKET_NAME` (o `BUCKET_NAME` como alternativa).

### 3.3 Google Drive — Sistema de Backups (`google_drive_backup_service.dart`, `project_backup_service.dart`)

Backups automáticos en Google Drive. Tres tipos:

| Tipo | Contenido | Formato |
|------|-----------|---------|
| `catalogs` | Todos los catálogos del usuario | JSON |
| `users` | Todos los usuarios (solo admin) | JSON |
| `project` | Datos de la app (AppSupport + AppDocuments) | ZIP |

**Flujo de creación:**
- Catálogos/usuarios: serialización JSON → `GoogleDriveBackupService.backupCatalogs/Users()` → sube a carpeta `Backups_CatalogoTablas` en Drive.
- Proyecto: `ProjectBackupService.createProjectZipInMemory()` crea ZIP en memoria (sin tocar disco) → `uploadProjectBackupFromBytes()` sube directamente a Drive. En macOS sandbox usa `getApplicationSupportDirectory()` + `getApplicationDocumentsDirectory()` en lugar de `Directory.current` (que apuntaría a la raíz del contenedor sandbox, incluyendo `Library/Caches/` con varios GB).

**Flujo de descarga (macOS):**
- Descarga los bytes desde Drive → los escribe en `~/Downloads/` con fallback a `getApplicationDocumentsDirectory()`.
- Bug conocido y resuelto: el `context` del `builder` del diálogo de detalles sobreescribía el `context` externo. Al hacer `Navigator.pop()` del diálogo, el contexto quedaba desmontado (`context.mounted = false`) antes de llegar al código de guardado. Fix: guardar `outerContext` antes de abrir el diálogo y pasarlo a la función de descarga.

**Listado (`files.list`):**
- Requiere `$fields: 'files(id,name,size,createdTime,mimeType)'` para obtener el tamaño (la API no lo devuelve por defecto).
- Query con OR para cubrir ambos prefijos de nombre: `name contains 'project_backup' OR name contains 'catalogo_backup'`.

---

## 4. Capa de configuración de entorno

### 4.1 Flujo de carga (`env_loader.dart`)

```
initEnv()
├─ Web / Android  →  loadFromAssets()   (.env bundleado como Flutter asset)
├─ macOS / iOS    →  loadFromAppleBundle()   (NSBundle mainBundle)
├─ Linux          →  loadFromLinuxBundle()   (junto al binario)
└─ fallback       →  loadFromSearchPaths()   (CWD, ~/.config/…, etc.)
```

Todas las rutas escriben en **`globalEnvMap`** y en **`dotenv.env`** para
garantizar compatibilidad con código que use cualquiera de los dos mecanismos.

### 4.2 Acceso a variables (`env_config.dart`)

`EnvConfig` expone getters estáticos con valores por defecto. Nunca se accede
a `dotenv.env` directamente fuera de `env_loader.dart`.

```dart
EnvConfig.mongoUri      // MONGO_URI
EnvConfig.mongoDb       // MONGO_DB
EnvConfig.useS3         // USE_S3 == 'true'
EnvConfig.bucketName    // S3_BUCKET_NAME ?? BUCKET_NAME
EnvConfig.awsRegion     // AWS_REGION ?? 'eu-central-1'
EnvConfig.validate()    // Comprueba mínimo requerido
```

---

## 5. Capa de presentación

### 5.1 Patrón MVVM

Los `ViewModel` extienden `ChangeNotifier`. Las `View` los consumen vía
`ChangeNotifierProvider` / `Consumer`. No hay BLoC ni Riverpod.

```
View  →  llama método del ViewModel
       ←  recibe notifyListeners() → rebuild
```

### 5.2 Inyección de dependencias (DI)

Los servicios se inyectan como parámetros opcionales en el constructor del
ViewModel. Si no se pasan, se usan las implementaciones reales. Esto permite
testear con mocks sin código generado:

```dart
AuthViewModel({
  MongoService? mongoService,
  KeychainService? keychainService,
}) : _mongoService = mongoService ?? MongoService(),
     _keychainService = keychainService ?? KeychainService();
```

### 5.3 Navegación

Navegación imperativa (`Navigator.push`) entre pantallas. No hay router declarativo.
Las rutas de administración están protegidas por comprobación de `user.isAdmin`.

---

## 6. Despliegue Web (Docker)

```
docker/
├── Dockerfile.web          # Multi-stage: Flutter builder + Caddy runtime
├── Caddyfile               # SPA routing + cabeceras de seguridad + caché
└── docker-compose.web.yml  # Orquestación con BuildKit secrets para .env
```

El `.env` se inyecta durante la build con `--mount=type=secret` y **no queda**
en ninguna capa de la imagen final. El binario web resultante no contiene
credenciales — las variables de entorno en web se leen del asset `.env` que
se bundlea en `build/web/assets/`.

```bash
docker compose -f docker/docker-compose.web.yml up -d \
  --build
```

Puerto por defecto: `8080`. Configurable con `WEB_PORT` en el entorno del host.

---

## 7. CI/CD (GitHub Actions)

`.github/workflows/flutter-ci.yml` ejecuta en cada push a `main`:

1. **Test & Analyze** (`ubuntu-latest`)
   - Crea `.env` placeholder (necesario para el asset)
   - `flutter pub get`
   - `flutter analyze --no-fatal-infos`
   - `flutter test`

2. **Build Web** (depende de Test & Analyze)
   - `flutter build web --release`

Los tests unitarios están en `test/utils/` y `test/viewmodels/`. No requieren
conexión a MongoDB ni a AWS — todos los servicios externos se mockean con `mocktail`.

---

## 8. Convenciones de catálogos

### 8.1 Columna Fecha

Al crear un catálogo, `create_catalog_dialog.dart` inserta automáticamente `'Fecha'`
como primera columna si el usuario no la ha incluido. En `add_edit_row_dialog.dart`:

- Columnas cuyo nombre sea `fecha` / empiece por `fecha` / contenga `fecha` (case-insensitive)
  se renderizan como campo de solo lectura con botón de calendario.
- El selector usa `showDatePicker()` nativo de Flutter.
- En filas nuevas, el valor por defecto es la fecha de hoy en formato `dd/MM/yyyy`.

### 8.2 File Picker en macOS sandbox

`FileType.image` en `file_picker` desactiva (greys out) los directorios en el sandbox
de macOS, impidiendo la navegación. Patrón correcto en toda la app:

```dart
// ❌ Evitar
FilePicker.platform.pickFiles(type: FileType.image)

// ✅ Correcto
FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'],
)
```

Afecta a: `profile_view.dart`, `admin_user_detail_view.dart`, `add_edit_row_dialog.dart`.

---

## 9. Herramientas y scripts

| Script | Propósito |
|--------|-----------|
| `scripts/cleanup_duplicate_catalogs.dart` | CLI para limpiar duplicados en MongoDB. Ver [docs/misc/cleanup-duplicate-catalogs.md](misc/cleanup-duplicate-catalogs.md) |
| `scripts/build_linux_release.sh` | Build de release para Linux en local |
| `scripts/build_linux_release_docker.sh` | Build de release Linux dentro de Docker |
| `scripts/ejecutar_linux_gui.sh` | Ejecutar la app Linux con DISPLAY |

---

## 10. Evolución del proyecto

| Versión | Hito |
|---------|------|
| Previa | `EDFCatalogoSwift` — app nativa macOS en SwiftUI (archivada) |
| v0.x | `edf_catalogotablas_macOS` — versión Flutter solo macOS |
| **v1.0.0** | `EDFCatalogoMultiplatform` — Flutter 6 plataformas, Docker Web, CI, tests |

El repositorio Swift original se mantiene como referencia histórica pero ya no
recibe actualizaciones. Todo el desarrollo futuro ocurre en este repo.
