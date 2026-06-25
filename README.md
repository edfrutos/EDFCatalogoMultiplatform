# EDF Catálogo Multiplatform

Aplicación Flutter para gestión de catálogos de tablas con soporte multiplataforma: **macOS · iOS · Android · Web · Windows · Linux**.

Backend: MongoDB Atlas · AWS S3 · Gmail SMTP.

---

## Plataformas

| Plataforma | Estado |
|-----------|--------|
| macOS | ✅ Nativo |
| iOS | ✅ Nativo |
| Android | ✅ Nativo |
| Web | ✅ Flutter Web + API Dart |
| Linux | 🐳 Docker (ver `docs/linux/`) |
| Windows | 🔄 Experimental |

---

## Requisitos

- Flutter ≥ 3.x · Dart ≥ 3.x — `flutter doctor`
- MongoDB Atlas, AWS S3 (credenciales en `.env`)
- Gmail App Password (notificaciones)

Copia `.env.example` → `.env` y rellena las variables.
Ver [`docs/setup/SETUP_ENV.md`](docs/setup/SETUP_ENV.md).

---

## Arranque por plataforma

### macOS / iOS / Android / Windows / Linux (nativo)

```bash
flutter pub get
flutter run -d macos      # macOS
flutter run -d ios        # iOS (simulador o dispositivo)
flutter run               # Android (dispositivo conectado)
flutter run -d windows    # Windows
flutter run -d linux      # Linux local
```

### Web

La versión web requiere el **servidor API Dart** (proxy hacia MongoDB y S3).
Variables `.env` necesarias: `MONGO_URI`, `MONGO_DB`, `API_JWT_SECRET`.

```bash
# Opción A — todo en uno (recomendado)
./scripts/dev_web.sh
# Arranca API en http://localhost:8089 + Flutter Web en Chrome. Ctrl+C detiene ambos.

# Opción B — procesos separados
./scripts/run_api_dev.sh          # Terminal 1: API (puerto 8089)
flutter run -d chrome             # Terminal 2: Flutter Web
```

> Si usas un puerto distinto para Flutter, actualiza `API_CORS_ORIGIN=http://localhost:<puerto>` en `.env`.

### macOS — distribuible (DMG)

```bash
./scripts/build_macos_dmg.sh
# → dist/EDFCatalogo-<version>.dmg  (firma ad-hoc, sin Developer ID)
```

### Web — producción (Docker)

```bash
docker compose -f docker/docker-compose.web.yml up -d --build
# Caddy en 80/443, API en 8089 interno
```

---

## Documentación

| Tema | Referencia |
|------|-----------|
| Arquitectura y decisiones de diseño | [`docs/arquitectura.md`](docs/arquitectura.md) |
| Configuración de entorno | [`docs/setup/`](docs/setup/) |
| iOS / Xcode | [`docs/ios/`](docs/ios/) |
| Android / Android Studio | [`docs/android/`](docs/android/) |
| Linux / Docker | [`docs/linux/`](docs/linux/) |
| Testing | [`docs/testing/`](docs/testing/) |
| Misc / comandos | [`docs/misc/`](docs/misc/) |

---

## Seguridad

Ver [`docs/misc/SECURITY_INCIDENT.md`](docs/misc/SECURITY_INCIDENT.md) — incidente de abril 2025 resuelto. Nunca commitear `.env`.

---

## Estructura del proyecto

```bash
lib/
├── models/          # Catalog, User, FileType, ColumnDefinition
├── services/        # Mongo, S3, Email, Keychain, Backup, Export
├── viewmodels/      # Auth, Catalog, Admin, Backup
├── views/screens/   # Todas las pantallas
└── utils/           # env_loader, logger, validators
```
