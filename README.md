# EDFCatalogoMultiplatform

Aplicación multiplataforma de catálogo desarrollada con Flutter para Windows, Linux (Ubuntu), iOS y Android.

## 🚀 Plataformas Soportadas

- **Windows** (Desktop)
- **Linux Ubuntu** (Desktop)
- **iOS** (Mobile)
- **Android** (Mobile)

## 📋 Requisitos Previos

### Flutter SDK
- Flutter SDK instalado y configurado
- Verificar instalación: `flutter doctor`

### Plataformas Específicas

#### Windows
- Windows 10 o superior
- Visual Studio 2019 o superior con las herramientas de desarrollo de C++
- Windows 10 SDK

#### Linux (Ubuntu)
- Ubuntu 18.04 o superior
- Clang
- CMake
- GTK development libraries

#### iOS
- macOS
- Xcode 14.0 o superior
- CocoaPods
- Un dispositivo iOS o simulador

#### Android
- Android Studio
- Android SDK
- Android SDK Platform-Tools
- Un dispositivo Android o emulador

## 🛠️ Instalación y Configuración

### 1. Clonar el repositorio
```bash
git clone <repository-url>
cd EDFCatalogoMultiplatform
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Verificar configuración
```bash
flutter doctor
```

### 4. Ejecutar la aplicación

**Windows:**
```bash
flutter run -d windows
```

**Linux:**
```bash
flutter run -d linux
```

**iOS:**
```bash
flutter run -d ios
```

**Android:**
```bash
flutter run -d android
```

## 📦 Estructura del Proyecto

```
EDFCatalogoMultiplatform/
├── lib/                    # Código fuente Dart
│   └── main.dart          # Punto de entrada
├── android/                # Configuración Android
├── ios/                    # Configuración iOS
├── linux/                  # Configuración Linux
├── windows/                # Configuración Windows
├── test/                   # Tests
└── pubspec.yaml           # Dependencias y configuración
```

## 🔧 Desarrollo

### Hot Reload
Flutter soporta hot reload para desarrollo rápido:
- Presiona `r` en la consola para hot reload
- Presiona `R` para hot restart
- Presiona `q` para salir

### Builds de Producción

**Windows:**
```bash
flutter build windows
```

**Linux:**
```bash
flutter build linux
```

**iOS:**
```bash
flutter build ios
```

**Android:**
```bash
flutter build apk          # APK
flutter build appbundle    # App Bundle (Google Play)
```

## 📚 Recursos

- [Documentación Flutter](https://docs.flutter.dev/)
- [Cookbook Flutter](https://docs.flutter.dev/cookbook)
- [API Reference](https://api.flutter.dev/)

## 📝 Notas

Este proyecto es la versión multiplataforma de EDFCatalogoSwift (aplicación macOS nativa), manteniendo la misma funcionalidad y arquitectura en todas las plataformas soportadas.

## 📄 Licencia

[Especificar licencia si es necesario]
