# 📚 EDFCatalogoMultiplatform - Documentación Centralizada

## 🎯 Visión General

Este proyecto implementa el mismo sistema de **gestión de catálogos de tablas** en **4 lenguajes de programación diferentes**, demostrando portabilidad de arquitectura y funcionalidad multiplataforma.

## 📦 Estructura de Directorios

```
EDFCatalogoMultiplatform/
├── languages/
│   ├── flutter/              # 🎯 Flutter (Dart) - Multiplataforma
│   │   ├── lib/             # Código fuente Dart
│   │   ├── test/            # Tests
│   │   ├── android/         # Configuración Android
│   │   ├── ios/             # Configuración iOS
│   │   ├── linux/           # Configuración Linux
│   │   ├── windows/         # Configuración Windows
│   │   ├── macos/           # Configuración macOS
│   │   ├── config/          # Configuración (.env)
│   │   ├── scripts/         # Scripts de testing
│   │   ├── pubspec.yaml     # Dependencias
│   │   └── README.md        # Documentación
│   │
│   ├── swift/               # 🖥️ Swift - macOS/iOS
│   │   ├── Sources/         # Código fuente Swift
│   │   ├── Tests/           # Tests XCTest
│   │   ├── Resources/       # Assets
│   │   ├── config/          # Configuración
│   │   ├── scripts/         # Scripts de testing
│   │   ├── Package.swift    # SPM Configuration
│   │   └── README.md        # Documentación
│   │
│   ├── csharp/              # 🌐 C# - Web/Desktop (.NET 9.0)
│   │   ├── Controllers/     # API Endpoints
│   │   ├── Models/          # Modelos de datos
│   │   ├── Services/        # Servicios
│   │   ├── Pages/           # Blazor Pages
│   │   ├── Components/      # Componentes Blazor
│   │   ├── Tests/           # xUnit Tests
│   │   ├── config/          # Configuración
│   │   ├── scripts/         # Scripts de testing
│   │   ├── Program.cs       # Configuración Principal
│   │   └── README.md        # Documentación
│   │
│   └── python/              # 🐍 Python - Web/macOS
│       ├── app/             # Aplicación Flask
│       ├── tests/           # Pytest
│       ├── tools/           # Herramientas CLI
│       ├── config/          # Configuración
│       ├── scripts/         # Scripts de testing
│       ├── run_server.py    # Servidor Flask
│       ├── requirements.txt # Dependencias
│       └── README.md        # Documentación
│
├── docker/                  # Configuración Docker (backup)
├── backup/                  # Backups de código original (backup)
└── TESTING_GUIDE.md        # Esta documentación
```

---

## 🚀 Inicio Rápido por Lenguaje

### 1️⃣ Flutter (Multiplataforma)

**Requisitos:** Flutter 3.9.2+, Dart 3.0+

```bash
cd languages/flutter

# Instalar dependencias
flutter pub get

# Ejecutar en tu plataforma
flutter run -d windows      # Windows
flutter run -d linux        # Linux
flutter run -d macos        # macOS
flutter run -d ios          # iOS (requiere macOS)
flutter run -d android      # Android

# Ejecutar tests
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
```

**Features:** Multiplataforma nativa, UI consistente, hot reload

---

### 2️⃣ Swift (macOS/iOS Nativo)

**Requisitos:** macOS 13.0+, Swift 5.9+, Xcode 15.0+

```bash
cd languages/swift

# Resolver dependencias
swift package resolve

# Ejecutar aplicación
swift run
# o abrir en Xcode:
# open Package.swift

# Ejecutar tests
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
```

**Features:** UI nativa SwiftUI, rendimiento óptimo, Keychain integration

---

### 3️⃣ C# .NET (Web/Desktop)

**Requisitos:** .NET 9.0 SDK, Visual Studio 2022 o VS Code

```bash
cd languages/csharp

# Restaurar dependencias
dotnet restore

# Ejecutar en desarrollo
dotnet run --environment Development
# Acceder: http://localhost:5005

# Ejecutar tests
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
```

**Features:** API REST con Swagger, Blazor Server, arquitectura empresarial

---

### 4️⃣ Python (Web/macOS)

**Requisitos:** Python 3.9+, pip

```bash
cd languages/python

# Crear entorno virtual
python3 -m venv venv
source venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt

# Ejecutar servidor
python run_server.py
# Acceder: http://localhost:5002

# Ejecutar como aplicación nativa macOS
python launcher_native_websockets.py

# Ejecutar tests
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
```

**Features:** Desarrollo rápido, PyWebView nativo macOS, CLI tools

---

## ✅ Checklist de Funcionalidad

### Flutter
- [x] Build para múltiples plataformas
- [x] State management con Provider
- [x] MongoDB integration
- [x] AWS S3 upload/download
- [x] Autenticación
- [x] Visualización de archivos
- [x] Tests implementados

### Swift
- [x] Interfaz SwiftUI nativa
- [x] MongoDB connection
- [x] AWS S3 integration
- [x] Keychain storage
- [x] Autenticación segura
- [x] Tests XCTest
- [x] macOS app bundle

### C# .NET
- [x] ASP.NET Core API
- [x] Blazor Server frontend
- [x] MongoDB integration
- [x] AWS S3 services
- [x] JWT authentication
- [x] Unit tests (xUnit)
- [x] Swagger API docs

### Python
- [x] Flask backend
- [x] HTML5 frontend
- [x] MongoDB connection
- [x] AWS S3 integration
- [x] PyWebView nativo macOS
- [x] Pytest suite
- [x] CLI tools

---

## 🧪 Ejecutar Todos los Tests

### Script maestro (ejecuta tests de todos los lenguajes)

```bash
#!/bin/bash
# Run tests for all languages

echo "🧪 Testing All Languages"
echo "========================="

# Flutter
echo -e "\n🎯 Testing Flutter..."
cd languages/flutter
./scripts/run_tests.sh
cd ../..

# Swift
echo -e "\n🖥️  Testing Swift..."
cd languages/swift
./scripts/run_tests.sh
cd ../..

# C#
echo -e "\n🌐 Testing C#..."
cd languages/csharp
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
cd ../..

# Python
echo -e "\n🐍 Testing Python..."
cd languages/python
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
cd ../..

echo -e "\n✅ All tests completed!"
```

---

## 📊 Comparativa de Tecnologías

| Aspecto | Flutter | Swift | C# | Python |
|--------|---------|-------|-----|--------|
| **Lenguaje** | Dart | Swift 5.9+ | C# 13 | Python 3.9+ |
| **Plataformas** | Win/Mac/Linux/iOS/Android | macOS/iOS | Windows/Web | Web/macOS |
| **Performance** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Curva Aprendizaje** | Media | Media-Alta | Baja | Baja |
| **Testing Framework** | flutter_test | XCTest | xUnit | pytest |
| **UI Framework** | Flutter Widgets | SwiftUI | Blazor | HTML5/Flask |
| **DB Integration** | mongo_dart | URLSession | Entity Framework | pymongo |
| **Estado Producción** | ✅ Listo | ✅ Listo | ✅ Listo | ✅ Listo |

---

## 📁 Archivos Compartidos

Los siguientes archivos se han duplicado en cada directorio de lenguaje:

- **`.env.example`** - Variables de entorno (template)
- **`README.md`** - Documentación específica del lenguaje
- **Configuración** - Archivos de configuración adaptados al lenguaje

---

## 🐛 Troubleshooting

### Flutter

```bash
# Limpiar y reconstruir
flutter clean
flutter pub get
flutter run -v

# Ver información de diagnóstico
flutter doctor -v
```

### Swift

```bash
# Limpiar build
swift package clean
rm -rf .build

# Resolver dependencias
swift package resolve

# Build verbose
swift build -v
```

### C# .NET

```bash
# Limpiar y reconstruir
dotnet clean
dotnet restore
dotnet build -v

# Ver información de .NET
dotnet --version
```

### Python

```bash
# Verificar entorno virtual
which python  # debe estar en venv/

# Reinstalar dependencias
pip install --upgrade -r requirements.txt

# Ver información
python --version
```

---

## 🔐 Configuración de Seguridad

Todos los proyectos requieren configuración en `.env`:

```bash
# MongoDB
MONGO_URI=mongodb+srv://usuario:password@cluster.mongodb.net/
MONGO_DB=nombre_base_datos

# AWS S3
S3_BUCKET_NAME=tu-bucket
AWS_ACCESS_KEY_ID=tu_access_key
AWS_SECRET_ACCESS_KEY=tu_secret_key
AWS_REGION=eu-central-1
USE_S3=true

# Email Service (Brevo)
BREVO_API_KEY=tu_api_key
```

⚠️ **IMPORTANTE:** Nunca commitear `.env` con credenciales reales.

---

## 📚 Documentación Específica

- **Flutter:** `/languages/flutter/README.md`
- **Swift:** `/languages/swift/README.md`
- **C#/.NET:** `/languages/csharp/README.md`
- **Python:** `/languages/python/README.md`

---

## 🚀 Publicación y Distribución

### Flutter
- Google Play Store (Android)
- Apple App Store (iOS)
- Microsoft Store (Windows)
- Snap Store (Linux)

### Swift
- App Store (macOS/iOS)
- DMG distribuible
- GitHub Releases

### C# .NET
- Docker container
- NuGet packages
- Self-contained executable

### Python
- PyPI (si es público)
- Docker container
- Standalone app (PyInstaller)

---

## 🤝 Contribuir

Para agregar funcionalidad:

1. Implementar en un lenguaje primero
2. Replicar lógica en los otros 3
3. Crear tests para cada implementación
4. Documentar cambios

---

## 📈 Estadísticas del Proyecto

- **Lenguajes:** 4 diferentes
- **Plataformas soportadas:** 6
- **Líneas de código (estimadas):** 15,000+
- **Test cases:** 50+
- **Características core:** 10+

---

## ✨ Características Implementadas en Todos los Lenguajes

✅ Autenticación de usuarios  
✅ CRUD de catálogos  
✅ CRUD de filas  
✅ Visualización de archivos  
✅ Upload a AWS S3  
✅ Descarga de archivos  
✅ Foto de perfil  
✅ Panel de administración  
✅ Exportación de datos  
✅ Backup y recuperación  

---

## 🎓 Casos de Uso

### Cuándo usar cada tecnología:

**Flutter:** Necesitas una app nativa multiplataforma con máxima reutilización de código

**Swift:** Quieres máximo rendimiento y UI nativa en macOS/iOS

**C# .NET:** Necesitas arquitectura empresarial con API REST robusto

**Python:** Desarrollo rápido, prototipado, o una app web ligera

---

## 📞 Soporte Técnico

Cada lenguaje tiene su propia sección de troubleshooting en su README.md

---

**Última actualización:** 2025  
**Versión:** 1.0.0  
**Estado:** ✅ Todos los proyectos funcionales y testeados
