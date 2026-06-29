# Arquitectura — EDFCatalogoMultiplatform

Documento de referencia de la arquitectura técnica del proyecto. Describe capas,
flujos de datos, decisiones de diseño y cómo se relacionan los módulos entre sí.

---

## 1. Visión general

EDFCatalogoMultiplatform es una aplicación Flutter que permite gestionar catálogos
de tablas con soporte multimedia. Corre en seis plataformas desde un único codebase:
**macOS, iOS, Android, Web, Linux y Windows**.

```sh
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

```sh
api/                               # Servidor API Dart/Shelf (solo para web)
├── bin/server.dart                # Punto de entrada HTTP
└── lib/
    ├── config.dart                # Configuración del servidor (puerto, CORS, BREVO_API_KEY, etc.)
    ├── auth/jwt_service.dart      # Autenticación JWT
    ├── db/mongo_db.dart           # Conexión MongoDB
    └── routes/
        ├── auth_routes.dart       # POST /api/auth/login (búsqueda case-insensitive)
        ├── contact_routes.dart    # POST /api/contact/ — guarda en 'contacts' + email Brevo
        ├── s3_routes.dart         # POST /api/s3/upload, GET /api/s3/presign
        ├── catalog_routes.dart    # CRUD catálogos
        ├── user_routes.dart       # CRUD usuarios (admin); email normalizado a minúsculas
        └── helpers.dart           # Utilidades compartidas

lib/
├── main.dart                  # Punto de entrada — llama a initEnv() y runApp()
├── models/                    # Entidades de dominio (User, Catalog, Row, …)
├── services/                  # Acceso a datos externos
│   ├── mongo_service.dart     # Todas las operaciones MongoDB + kIsWeb guards
│   ├── api_service.dart       # Cliente HTTP para el servidor API (solo web)
│   ├── email_service.dart     # Envío de emails vía Brevo (nativo; en web lo hace la API)
│   ├── s3_service.dart        # Upload/download en AWS S3
│   ├── keychain_service.dart  # Persistencia segura de sesión
│   └── export_service.dart    # Exportación (PDF, CSV, Excel, compartir)
├── viewmodels/                # Lógica de presentación (ChangeNotifier)
│   └── auth_viewmodel.dart    # Estado de autenticación
├── views/
│   ├── screens/               # Pantallas completas
│   │   ├── admin_*/           # Pantallas de administración
│   │   ├── contact_view.dart  # Formulario de contacto
│   │   └── widgets/           # Widgets reutilizables entre pantallas
│   └── …
└── utils/
    ├── env_loader.dart           # Carga de .env multiplataforma + globalEnvMap
    ├── env_config.dart           # Getters tipados sobre las variables de entorno
    ├── io_stub.dart              # Stub dart:io File/Directory para web
    ├── web_download.dart         # Descarga Blob en browser (web only)
    ├── web_download_stub.dart    # Stub para plataformas nativas
    ├── web_pdf_view.dart         # Visor PDF via <iframe> (web only)
    └── web_pdf_view_stub.dart    # Stub para plataformas nativas
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

```sh
mongodb+srv://<user>:<pass>@<cluster>/<db>?retryWrites=true&w=majority
```

### 3.2 AWS S3 (`s3_service.dart` + `api_service.dart`)

Almacenamiento de archivos multimedia (imágenes, vídeos, documentos adjuntos a filas).
Se activa únicamente cuando `USE_S3=true` en `.env`. Si está desactivado, los archivos
se guardan en local o no se adjuntan.

Credenciales necesarias: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`,
`S3_BUCKET_NAME` (o `BUCKET_NAME` como alternativa).

**Diferencia por plataforma en el upload:**

| Plataforma | Ruta | Servicio usado |

|-----------|------|----------------|
| macOS / iOS / Android | path local del archivo | `S3Service.uploadFile(filePath)` → SDK AWS directo |
| Web | bytes del `PlatformFile` | `ApiService.instance.uploadBytes(bytes, fileName, folder, contentType)` → POST al servidor API → SDK AWS en servidor |

El servidor API recibe el `Content-Type` del header HTTP y lo aplica al `PutObject` de S3.
**Crítico**: si se omite `contentType`, S3 almacena `application/octet-stream` y Chrome
descarga el archivo en vez de mostrarlo inline (p. ej. PDFs en el visor `<iframe>`).

Mapa de extensiones → MIME types definido en `add_edit_row_dialog.dart > uploadPlatformFile()`:

```dart
const mimeByExt = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg', 'png': 'image/png',
  'mp4': 'video/mp4', 'mov': 'video/quicktime',
  // … ver código fuente para la tabla completa
};
```

**Presigned URLs**: `S3Service.getPresignedUrl(key)` genera una URL temporal firmada
para descarga directa desde S3 (sin pasar por el servidor). En web delega a
`ApiService.instance.getPresignedUrl(key)` vía GET `/api/s3/presign?key=…`.

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

```sh
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

```sh
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

## 6. Despliegue Web (Docker + API Dart)

### 6.1 Servidor API Dart (`api/`)

El servidor API es necesario en web porque:

- `dart:io` no está disponible en browser → no puede conectar directo a MongoDB ni a AWS SDK
- El servidor actúa como proxy seguro: recibe requests de Flutter Web y se comunica con MongoDB y S3

```sh
api/
├── bin/server.dart          # shelf_router, middleware CORS + JWT
└── lib/
    ├── config.dart          # API_PORT (default 8089), API_CORS_ORIGIN, JWT_SECRET
    ├── auth/jwt_service.dart
    ├── db/mongo_db.dart
    └── routes/              # /api/auth, /api/s3, /api/catalog, /api/users, /api/health
```

#### Requisitos previos

| Herramienta | Verificación |

|------------|-------------|
| Flutter SDK | `flutter --version` |
| Dart SDK (incluido en Flutter) | `dart --version` |
| Google Chrome | debe estar instalado |
| `.env` en la raíz del proyecto | ver variables necesarias abajo |

Variables mínimas en `.env` para que el servidor API arranque:

```dotenv
MONGO_URI=mongodb+srv://user:pass@cluster/
MONGO_DB=nombre_base_de_datos
API_JWT_SECRET=una_cadena_larga_y_segura

# Opcionales — para upload S3 desde web
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=eu-central-1
S3_BUCKET_NAME=nombre-bucket

# Puerto de la API (por defecto 8089)
API_PORT=8089

# CORS — debe coincidir con la URL de Flutter Web en desarrollo
API_CORS_ORIGIN=http://localhost:PORT_FLUTTER
```

> **Puerto**: se usa **8089** (no 8080) porque Docker Desktop ocupa el 8080
> permanentemente en macOS independientemente de si hay contenedores activos.

#### Arranque en desarrollo (opción recomendada)

```bash
# Desde la raíz del proyecto:
./scripts/dev_web.sh
```

El script hace internamente:

1. Carga `.env` en el entorno del proceso
2. Ejecuta `dart pub get` en `api/` si faltan dependencias
3. Mata cualquier proceso previo en el puerto 8089
4. Arranca `dart run api/bin/server.dart` en background (log → `.api_dev.log`)
5. Espera hasta 15 s a que `/api/health` responda
6. Lanza `flutter run -d chrome` en primer plano
7. Al pulsar Ctrl+C, mata el servidor API antes de salir

#### Arranque manual (paso a paso)

Si se necesita controlar cada proceso por separado:

```bash
# Terminal 1 — API
./scripts/run_api_dev.sh
# Verifica que arranca: curl http://localhost:8089/api/health

# Terminal 2 — Flutter Web
flutter run -d chrome --web-port 8080
```

> `--web-port` fija el puerto de Flutter Web. Si se usa un puerto distinto del
> esperado en `API_CORS_ORIGIN`, el navegador bloqueará las peticiones por CORS.
> Asegúrate de que `API_CORS_ORIGIN=http://localhost:<web-port>` en `.env`.
>
> **Nota**: `--web-renderer` se eliminó en Flutter 3.22+. Ya no es necesario especificarlo.

#### Solo la API (debug aislado)

```bash
./scripts/run_api_dev.sh
# Log en tiempo real (si se usa dev_web.sh en otro terminal):
tail -f .api_dev.log
```

#### Verificar que la API está funcionando

```bash
# Health check
curl http://localhost:8089/api/health

# Login de prueba
curl -X POST http://localhost:8089/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"pass"}'
```

#### Problemas frecuentes en desarrollo web

| Síntoma | Causa probable | Solución |

|---------|---------------|----------|
| `XMLHttpRequest error` en Flutter | CORS bloqueado | Revisar `API_CORS_ORIGIN` en `.env`; debe ser exactamente la URL de Chrome |
| API no arranca — "port in use" | Proceso anterior no terminó | `lsof -ti tcp:8089 \| xargs kill` |
| `Failed to connect to MongoDB` | `MONGO_URI` incorrecto o red | Verificar URI y que el cluster permite la IP actual |
| Pantalla en blanco en Chrome | Error en build JS | Abrir DevTools → Console para ver el error real |
| `.env` no se carga | Script ejecutado desde subdirectorio | Ejecutar siempre desde la raíz: `./scripts/dev_web.sh` |
| Pantalla en blanco en iPhone/iPad | `flutter run` inyecta WebSocket de debug (`ws://127.0.0.1:PORT`); desde el móvil, `127.0.0.1` apunta al propio móvil → conexión falla | Usar `./scripts/dev_tailscale.sh` (build release, sin WebSocket). Ver §6.3 |
| `502 Bad Gateway` en Tailscale `:8444` | API Dart no está corriendo | `./scripts/run_api_dev.sh` o `tmux attach -t edf` → ventana `api` |

### 6.2 Docker para producción (self-contained con Caddy)

```sh
docker/
├── Dockerfile.api          # Imagen Dart AOT (FROM scratch)
├── Caddyfile.web           # Reverse proxy: Flutter Web (/) + API (/api/)
└── docker-compose.web.yml  # Servicios: caddy + api
```

```bash
docker-compose -f docker/docker-compose.web.yml up -d --build
```

Puerto web por defecto: `80/443` (Caddy con HTTPS automático).
El servidor API escucha en `8089` internamente; Caddy hace el proxy.

### 6.2.1 VPS con Plesk/Nginx como proxy inverso

Producción en `https://edfcat.efjdefrutos.com` (Vultr, Ubuntu, Plesk).
Nginx/Plesk gestiona SSL (Let's Encrypt) y sirve directamente los ficheros estáticos.
Docker solo corre el contenedor de la API.

```
Internet → Plesk/Nginx :443 (SSL)
              │
              ├── /       → webroot Plesk (ficheros Flutter estáticos)
              └── /api/   → localhost:8089 (Docker, API Dart)
```

**Archivos:**
- `docker/docker-compose.prod.yml` — solo la API Dart en `127.0.0.1:8089`
- `scripts/deploy.sh` — build Flutter local → rsync al servidor → restart API

**Primer despliegue en el servidor (una vez):**
```bash
ssh -p 2222 root@208.76.221.20
git clone <repo> /opt/edfcatalogo
cd /opt/edfcatalogo && cp .env.example .env  # rellenar producción
docker compose -f docker/docker-compose.prod.yml up -d --build
```

**Directivas adicionales de Nginx en Plesk** (`edfcat.efjdefrutos.com`):
```nginx
location / {
    try_files $uri $uri/ /index.html;
}

location /api/ {
    proxy_pass http://127.0.0.1:8089;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

> **Nota**: el webroot de Plesk apunta al raíz del dominio
> (`/var/www/vhosts/efjdefrutos.com/edfcat.efjdefrutos.com/`),
> **no** al subdirectorio `httpdocs/`. El `rsync` de `deploy.sh` apunta
> al raíz del dominio para que Nginx encuentre los ficheros correctamente.
> `try_files $uri $uri/ /index.html` es necesario para el router de Flutter (SPA).

**Despliegues posteriores desde el Mac:**
```bash
./scripts/deploy.sh
```

### 6.3 Tailscale — acceso remoto desde iPhone/iPad

`dev_tailscale.sh` expone la app en la red Tailscale (HTTPS automático, sin abrir puertos en el router).

#### Por qué no funciona `flutter run` desde el móvil

En modo desarrollo, Flutter inyecta un WebSocket de debug que intenta conectar a `ws://127.0.0.1:<PUERTO>`. Desde un iPhone, `127.0.0.1` apunta al propio iPhone → el WebSocket falla → la app se queda en blanco. La solución es un **build release** (`flutter build web --release`), que no contiene ningún WebSocket de debug.

#### Arquitectura de puertos

```
iPhone/iPad
  │
  │  HTTPS (Tailscale TLS automático)
  ├─── :8443  ──▶  python3 http.server :56001  ──▶  build/web/ (Flutter release)
  └─── :8444  ──▶  dart run api/ :8089          ──▶  MongoDB Atlas / S3
```

**Por qué dos puertos HTTPS en lugar de path routing:**
Tailscale Serve con `--set-path /api` elimina el prefijo `/api` al hacer el proxy:
`https://.../api/auth/login` → backend recibe `/auth/login` → 404.
Con un puerto HTTPS dedicado (`:8444`) el path llega intacto al backend Dart.

#### Detección de entorno en `lib/utils/env_config.dart`

```dart
static String get apiBaseUrl {
  if (kIsWeb) {
    final pageHost = Uri.base.host;
    final isLocal = pageHost == 'localhost' ||
        pageHost == '127.0.0.1' ||
        pageHost == '0.0.0.0' ||  // Python http.server bind address
        pageHost == '';

    if (!isLocal) {
      // Acceso remoto: misma IP/host que la página web, pero puerto 8444
      const apiPort = String.fromEnvironment('TAILSCALE_API_PORT', defaultValue: '8444');
      return '${Uri.base.scheme}://${Uri.base.host}:$apiPort';
    }
    // Local: usar API_BASE_URL del .env
    return getEnvVariable('API_BASE_URL');
  }
  return getEnvVariable('API_BASE_URL');
}
```

#### Uso

```bash
# Arranque completo (build + API + web + Tailscale)
./scripts/dev_tailscale.sh

# La URL de acceso se muestra al final. También:
tailscale serve status

# Reconectar a los procesos
tmux attach -t edf       # Ctrl+B 0 → API  |  Ctrl+B 1 → Web
tmux kill-session -t edf # Parar todo

# Rebuild tras cambios de código
# Opción A — desde terminal:
flutter build web --release  # luego el servidor Python ya sirve el nuevo build

# Opción B — desde tmux:
# Ctrl+B 1 → ventana web → Ctrl+C → flecha↑ → Enter
```

#### Variables `.env` relevantes

```dotenv
API_PORT=8089          # Puerto interno de la API Dart
WEB_PORT=56001         # Puerto del servidor Python (ficheros estáticos)
HTTPS_PORT=8443        # Puerto HTTPS Tailscale para la app web
API_HTTPS_PORT=8444    # Puerto HTTPS Tailscale para la API
```

---

## 7. CI/CD (GitHub Actions)

`.github/workflows/flutter-ci.yml` ejecuta en cada push a `main`:

1. **Test & Analyze** (`ubuntu-latest`)
   - Crea `.env` placeholder (necesario para el asset)
   - `flutter pub get`
   - `flutter analyze --no-fatal-infos`
   - `flutter test` — tests unitarios + widget tests con mocks

2. **E2E Tests — Chrome headless** (depende de Test & Analyze)
   - `flutter test integration_test/ -d chrome --headless`
   - 5 tests E2E: arranque sin excepciones, pantalla login visible,
     validación de formulario vacío, entrada de texto, árbol de semántica
   - No requieren MongoDB — la app muestra login antes de cualquier conexión

3. **Build Web** (depende de E2E Tests)
   - `flutter build web --release`

4. **Build Android AAB** (depende de E2E Tests)
   - Decodifica keystore desde `ANDROID_KEYSTORE_BASE64` secret
   - `flutter build appbundle --release`

5. **Deploy Web** (solo en push a `main`, depende de Build Web)
   - Build con `.env` real (secret `DEPLOY_ENV_FILE`)
   - `rsync` al servidor Vultr/Plesk
   - Reinicia el contenedor Docker API

Los tests unitarios y de widget están en `test/` (no requieren dispositivo ni
conexión externa — todos los servicios se mockean con `mocktail`).
Los tests E2E están en `integration_test/` y se ejecutan en Chrome headless en CI.

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
| `scripts/dev_web.sh` | Arranca API Dart (puerto 8089) + Flutter Web en Chrome en paralelo. Ctrl+C mata ambos |
| `scripts/dev_tailscale.sh` | Acceso remoto desde iPhone/iPad via Tailscale. Hace un **build release** (sin WebSocket de debug), sirve los ficheros estáticos con Python en el puerto 56001, arranca la API Dart en 8089 y configura dos puertos HTTPS en Tailscale Serve (8443 → web, 8444 → API). Todo en sesión **tmux** persistente. `tmux attach -t edf` para reconectar. Ver §6.3 |
| `scripts/run_api_dev.sh` | Solo la API Dart (para debug aislado) |
| `scripts/build_macos_dmg.sh` | Build release macOS → firma ad-hoc → DMG con hdiutil |
| `scripts/build_linux_release.sh` | Build de release para Linux en local |
| `scripts/build_linux_release_docker.sh` | Build de release Linux dentro de Docker |
| `scripts/ejecutar_linux_gui.sh` | Ejecutar la app Linux con DISPLAY |
| `scripts/cleanup_duplicate_catalogs.dart` | CLI para limpiar duplicados en MongoDB. Ver [docs/misc/cleanup-duplicate-catalogs.md](misc/cleanup-duplicate-catalogs.md) |

### 9.1 `build_macos_dmg.sh` — detalles de codesign

El script aplica firma ad-hoc (no distribuible en App Store, válida para uso local/intranet).
Orden estricto de firma ("inside-out") requerido por codesign:

1. `.dylib` sueltos en `Contents/Frameworks/`
2. Binarios internos de cada `.framework` + el bundle `.framework`
3. Binario en `Contents/MacOS/` — **usa `find -exec` para evitar problemas con nombres con acentos (NFD/NFC) en bash pipes**
4. El bundle `.app` completo — **con `--entitlements macos/Runner/Release.entitlements`** para que el sandbox permita `FilePicker.getDirectoryPath()`

**Problema conocido resuelto**: `hdiutil create` falla con "Recurso ocupado" si el
TMP_DMG anterior quedó montado. El script ahora: (a) detacha el volumen, (b) espera
1 segundo, (c) elimina el archivo antes de crear uno nuevo.

---

## 10. Gotchas de plataforma

### 10.1 Web — `dart:io` vs `io_stub.dart`

Flutter Web no incluye `dart:io`. El import condicional:

```dart
import 'dart:io' if (dart.library.html) 'package:edfcatalogomultiplatform/utils/io_stub.dart';
```

hace que en web `File` resuelva a la clase stub. dart2js verifica tipos en **todas** las
ramas del código incluso las protegidas con `!kIsWeb`, por lo que una asignación
`FileImage(File(path))` produce error de tipos en build web aunque nunca ejecute.

**Fix**: `File(_selectedPlatformFile!.path!) as dynamic` — el cast a `dynamic`
omite la verificación de tipos de dart2js. Patrón ya extendido a todos los sites de uso.

### 10.2 Web — `html.Blob` y encoding

`html.Blob([parts], mimeType, endings)` solo acepta `'transparent'` o `'native'`
como tercer argumento (`endings`). Pasar `'utf-8'` lanza:

```sh
TypeError: ... 'utf-8' is not a valid enum value of type EndingType
```

**Fix**: codificar a bytes antes de crear el Blob:

```dart
final bytes = utf8.encode(content);
final blob = html.Blob([bytes], mimeType);  // sin tercer argumento
```

### 10.3 Web — File Picker con `PlatformFile`

Para que el mismo código funcione en web y nativo se usa `file_picker.PlatformFile`
con `withData: true`. Esto rellena tanto `pf.bytes` (web) como `pf.path` (nativo):

```dart
// Web
Image.memory(_selectedPlatformFile!.bytes!, fit: BoxFit.cover)
ApiService.instance.uploadBytes(bytes: pf.bytes!, ...)

// Nativo
Image.file(File(_selectedPlatformFile!.path!) as dynamic, ...)
S3Service().uploadFile(filePath: pf.path!, ...)
```

### 10.4 macOS — Sandbox y entitlements

`codesign --sign - app.app` sin `--entitlements` NO embebe el archivo `.entitlements`
aunque exista en el proyecto. Resultado: `ENTITLEMENT_NOT_FOUND` al llamar a
`FilePicker.platform.getDirectoryPath()` en runtime.

Siempre usar:

```bash
codesign --force --sign - --entitlements macos/Runner/Release.entitlements app.app
```

### 10.5 macOS — codesign con nombres no-ASCII

`find ... | while read -r bin; do codesign ... "$bin"; done` puede fallar silenciosamente
con binarios cuyos paths contienen caracteres con acento (NFD en HFS+, NFC en la shell).
**Fix**: usar `find -exec` para que codesign reciba el path directamente del kernel:

```bash
find "${APP_PATH}/Contents/MacOS" -type f \
  -exec codesign --force --sign - {} \;
```

---

## 11. Evolución del proyecto

| Versión | Hito |
|---------|------|
| Previa | `EDFCatalogoSwift` — app nativa macOS en SwiftUI (archivada) |
| v0.x | `edf_catalogotablas_macOS` — versión Flutter solo macOS |
| **v1.0.0** | `EDFCatalogoMultiplatform` — Flutter 6 plataformas, Docker Web, CI, tests |
| **v1.1.0** | Soporte web completo: servidor API Dart/Shelf, uploads S3 vía API con Content-Type correcto, visor PDF inline, export CSV fix, scripts dev_web.sh, build_macos_dmg.sh con entitlements |
| **v1.2.0** | Fixes web + E2E: login case-insensitive (MongoDB regex), email normalizado a minúsculas en creación de usuario, dark mode chips visibles (surfaceContainerHigh), formulario de contacto funcional en web (kIsWeb guard + ruta API POST /api/contact/ con notificación Brevo), 5 tests E2E Chrome headless, job CI test-e2e, Android key.properties.example, fix build macOS DMG en Xcode 26 beta (CODE_SIGNING_ALLOWED=NO en Flutter-Release.xcconfig) |

El repositorio Swift original se mantiene como referencia histórica pero ya no
recibe actualizaciones. Todo el desarrollo futuro ocurre en este repo.
