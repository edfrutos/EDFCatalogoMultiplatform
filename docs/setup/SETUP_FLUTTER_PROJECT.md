# 🚀 Guía de Configuración del Proyecto Flutter Multiplataforma

## 📋 Resumen

Este documento describe cómo crear el nuevo repositorio y proyecto Flutter para la versión multiplataforma de **EDF Catálogo de Tablas**.

---

## 🎯 Estructura Recomendada

### Nombre del Proyecto
```
EDFCatalogoFlutter
```
o
```
EDFCatalogoMultiplatform
```

### Repositorio GitHub
- **Nombre:** `EDFCatalogoFlutter` o `EDFCatalogoMultiplatform`
- **Descripción:** "Aplicación multiplataforma de gestión de catálogos (Windows, Linux, iOS, Android)"
- **Visibilidad:** Privado (si contiene credenciales) o Público

---

## 📁 Estructura de Directorios Propuesta

```
EDFCatalogoFlutter/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .gitignore
├── pubspec.yaml                 # Dependencias Flutter
├── analysis_options.yaml        # Reglas de análisis de código
├── lib/
│   ├── main.dart               # Punto de entrada
│   ├── app.dart                # Configuración de la app
│   ├── models/                 # Modelos de datos
│   │   ├── user.dart
│   │   ├── catalog.dart
│   │   ├── catalog_row.dart
│   │   └── row_files.dart
│   ├── services/               # Servicios backend
│   │   ├── mongo_service.dart
│   │   ├── s3_service.dart
│   │   ├── email_service.dart
│   │   └── storage_service.dart
│   ├── viewmodels/             # Lógica de negocio
│   │   ├── auth_viewmodel.dart
│   │   ├── catalog_viewmodel.dart
│   │   └── admin_viewmodel.dart
│   ├── views/                  # Interfaces de usuario
│   │   ├── login/
│   │   │   ├── login_screen.dart
│   │   │   └── widgets/
│   │   ├── catalogs/
│   │   │   ├── catalogs_screen.dart
│   │   │   ├── catalog_detail_screen.dart
│   │   │   └── widgets/
│   │   ├── profile/
│   │   │   └── profile_screen.dart
│   │   └── admin/
│   │       ├── admin_screen.dart
│   │       └── widgets/
│   ├── widgets/                # Widgets reutilizables
│   │   ├── custom_button.dart
│   │   ├── file_viewer.dart
│   │   └── ...
│   └── utils/                  # Utilidades
│       ├── validators.dart
│       ├── constants.dart
│       └── helpers.dart
├── test/                       # Tests unitarios
│   ├── models/
│   ├── services/
│   └── viewmodels/
├── integration_test/           # Tests de integración
├── assets/                     # Recursos
│   ├── images/
│   ├── icons/
│   └── fonts/
├── android/                    # Configuración Android
├── ios/                        # Configuración iOS
├── linux/                      # Configuración Linux
├── windows/                    # Configuración Windows
├── macos/                      # Configuración macOS (opcional)
└── web/                        # Configuración Web (opcional, futuro)

```

---

## 🛠️ Pasos de Configuración

### 1. Instalar Flutter

#### macOS/Linux:
```bash
# Descargar Flutter SDK
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verificar instalación
flutter doctor
```

#### Windows:
```powershell
# Descargar desde: https://flutter.dev/docs/get-started/install/windows
# O usar Chocolatey:
choco install flutter
```

### 2. Crear el Proyecto Flutter

```bash
# Navegar al directorio de proyectos
cd /Users/edefrutos/__Proyectos

# Crear proyecto Flutter
flutter create --org com.edefrutos --platforms=windows,linux,ios,android EDFCatalogoFlutter

# Navegar al proyecto
cd EDFCatalogoFlutter
```

### 3. Configurar Dependencias (pubspec.yaml)

```yaml
name: edf_catalogo_flutter
description: Aplicación multiplataforma de gestión de catálogos
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # Estado y gestión de datos
  provider: ^6.1.1
  get_it: ^7.6.4
  
  # Base de datos y backend
  mongo_dart: ^0.7.3
  http: ^1.1.0
  dio: ^5.4.0
  
  # AWS S3
  aws_s3_upload: ^1.0.0
  aws_signature_v4: ^1.2.0
  
  # Almacenamiento seguro
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.2
  
  # UI
  cupertino_icons: ^1.0.6
  flutter_svg: ^2.0.9
  cached_network_image: ^3.3.0
  file_picker: ^6.1.1
  
  # Utils
  intl: ^0.19.0
  path_provider: ^2.1.1
  url_launcher: ^6.2.2
  
  # Gestión de archivos
  pdf_viewer: ^1.2.0
  video_player: ^2.8.1
  image_picker: ^1.0.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.7
```

### 4. Inicializar Git

```bash
cd EDFCatalogoFlutter

# Inicializar repositorio
git init

# Crear .gitignore específico de Flutter
# (Flutter ya crea uno por defecto, pero podemos mejorarlo)

# Commit inicial
git add .
git commit -m "Initial commit: Flutter multiplataforma setup"
```

### 5. Crear Repositorio en GitHub

#### Opción A: Desde GitHub Web
1. Ir a GitHub.com
2. Click en "New Repository"
3. Nombre: `EDFCatalogoFlutter`
4. Descripción: "Aplicación multiplataforma de gestión de catálogos"
5. **Privado** (recomendado si contiene credenciales)
6. **NO** inicializar con README (ya lo creamos localmente)

#### Opción B: Desde terminal
```bash
# Conectarse al repositorio remoto
git remote add origin https://github.com/edfrutos/EDFCatalogoFlutter.git

# Push inicial
git branch -M main
git push -u origin main
```

---

## 📝 Archivos Iniciales a Crear

### 1. README.md
```markdown
# EDF Catálogo de Tablas - Multiplataforma

Aplicación multiplataforma para gestión de catálogos desarrollada con Flutter.

## Plataformas Soportadas
- 🪟 Windows
- 🐧 Linux (Ubuntu)
- 📱 iOS
- 🤖 Android

## Tecnologías
- Flutter/Dart
- MongoDB Atlas
- AWS S3
- Brevo (Email)

## Instalación
[Instrucciones de instalación]

## Desarrollo
[Instrucciones de desarrollo]
```

### 2. .env.example
```
# MongoDB
MONGO_URI=mongodb+srv://usuario:contraseña@cluster.mongodb.net/edf_catalogotablas
MONGO_DB=edf_catalogotablas

# AWS S3
AWS_ACCESS_KEY_ID=tu_clave_de_acceso
AWS_SECRET_ACCESS_KEY=tu_clave_secreta
AWS_REGION=eu-central-1
S3_BUCKET_NAME=edf-catalogo-tablas

# Brevo (Email)
BREVO_API_KEY=tu_api_key
```

### 3. CHANGELOG.md
```markdown
# Changelog

## [1.0.0] - 2025-10-31
### Added
- Proyecto inicial Flutter
- Estructura básica multiplataforma
```

---

## 🔧 Configuración por Plataforma

### Windows
- Requiere Visual Studio con componentes C++
- Habilitar soporte Windows en Flutter:
```bash
flutter config --enable-windows-desktop
```

### Linux
- Requiere dependencias del sistema:
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```
- Habilitar soporte Linux:
```bash
flutter config --enable-linux-desktop
```

### iOS
- Requiere macOS y Xcode
- Configurar en `ios/Runner.xcodeproj`
- Certificados de desarrollador Apple

### Android
- Requiere Android Studio
- Configurar en `android/app/build.gradle`
- Keystore para firma de releases

---

## 📦 Scripts Útiles

### build_all.sh
```bash
#!/bin/bash
# Compilar para todas las plataformas

echo "Building for Windows..."
flutter build windows

echo "Building for Linux..."
flutter build linux

echo "Building for iOS..."
flutter build ios

echo "Building for Android..."
flutter build apk
```

### run_dev.sh
```bash
#!/bin/bash
# Ejecutar en modo desarrollo

PLATFORM=${1:-windows}

case $PLATFORM in
  windows)
    flutter run -d windows
    ;;
  linux)
    flutter run -d linux
    ;;
  ios)
    flutter run -d ios
    ;;
  android)
    flutter run -d android
    ;;
  *)
    echo "Plataforma no válida"
    ;;
esac
```

---

## 🔐 Gestión de Credenciales

### Flutter: flutter_dotenv

```yaml
# pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

```dart
// lib/main.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  // ...
}
```

**⚠️ IMPORTANTE:** Nunca commitear el archivo `.env` real, solo `.env.example`

---

## 🎯 Próximos Pasos

1. ✅ Crear repositorio local
2. ✅ Configurar estructura básica
3. ✅ Añadir dependencias principales
4. ✅ Crear modelos base (User, Catalog, etc.)
5. ✅ Implementar servicios (MongoDB, S3)
6. ✅ Crear vistas de login
7. ✅ Implementar autenticación
8. ✅ Portar funcionalidades principales

---

## 📚 Referencias

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Flutter Desktop](https://docs.flutter.dev/desktop)
- [Flutter Mobile](https://docs.flutter.dev/get-started/flutter-for/mobile)

---

**Última actualización:** 31 de Octubre 2025

