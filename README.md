# EDF Catálogo Multiplatform

Aplicación Flutter para gestión de catálogos de tablas con soporte multiplataforma: **macOS · iOS · Android · Web · Windows · Linux**.

Backend: MongoDB Atlas · AWS S3 · Gmail SMTP.

---

## Plataformas

| Plataforma | Estado |
|---|---|
| macOS | ✅ Nativo |
| iOS | ✅ Nativo |
| Android | ✅ Nativo |
| Web | ✅ Flutter Web |
| Linux | 🐳 Docker (ver `docs/linux/`) |
| Windows | 🔄 Experimental |

---

## Requisitos

- Flutter ≥ 3.x (`flutter doctor`)
- Dart ≥ 3.x
- MongoDB Atlas (URI en `.env`)
- AWS S3 (credenciales en `.env`)
- Gmail App Password (para notificaciones)

Copia `.env.example` → `.env` y rellena las variables. Ver [`docs/setup/SETUP_ENV.md`](docs/setup/SETUP_ENV.md).

---

## Arranque rápido

```bash
flutter pub get
flutter run -d macos      # macOS
flutter run -d chrome     # Web
flutter run               # dispositivo conectado
```

---

## Documentación

| Tema | Carpeta |
|---|---|
| Configuración inicial | [`docs/setup/`](docs/setup/) |
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

```
lib/
├── models/          # Catalog, User, FileType, ColumnDefinition
├── services/        # Mongo, S3, Email, Keychain, Backup, Export
├── viewmodels/      # Auth, Catalog, Admin, Backup
├── views/screens/   # Todas las pantallas
└── utils/           # env_loader, logger, validators
```
