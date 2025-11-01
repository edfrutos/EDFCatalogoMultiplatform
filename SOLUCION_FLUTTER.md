# 🔧 Solución: "permission denied: flutter"

## 🔍 Diagnóstico

El error "permission denied: flutter" generalmente significa que:
1. Flutter no está en el PATH
2. Flutter no está instalado
3. Los permisos del ejecutable están incorrectos

---

## ✅ Solución 1: Flutter está instalado pero no en PATH

### Paso 1: Encontrar Flutter

```bash
# Buscar Flutter en ubicaciones comunes
ls -la ~/flutter/bin/flutter 2>/dev/null
ls -la ~/development/flutter/bin/flutter 2>/dev/null
ls -la /opt/flutter/bin/flutter 2>/dev/null

# O buscar en todo el sistema (puede tardar)
find ~ -name "flutter" -type f -path "*/bin/flutter" 2>/dev/null
```

### Paso 2: Añadir Flutter al PATH

Edita tu archivo `~/.zshrc`:

```bash
nano ~/.zshrc
# o
code ~/.zshrc
```

Añade esta línea (reemplaza `/ruta/a/flutter` con la ruta real):

```bash
export PATH="$PATH:$HOME/flutter/bin"
# o si está en otra ubicación:
# export PATH="$PATH:/ruta/completa/a/flutter/bin"
```

Guarda y recarga:

```bash
source ~/.zshrc
```

### Paso 3: Verificar

```bash
flutter --version
which flutter
```

---

## ✅ Solución 2: Usar Ruta Completa Temporalmente

Si prefieres no modificar el PATH, puedes usar la ruta completa:

```bash
# Reemplaza /ruta/completa/a/flutter con tu ruta real
/ruta/completa/a/flutter/bin/flutter pub get
/ruta/completa/a/flutter/bin/flutter analyze
/ruta/completa/a/flutter/bin/flutter run
```

---

## ✅ Solución 3: Flutter NO está instalado

### Instalación en macOS

```bash
# 1. Descargar Flutter
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# 2. Añadir al PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# 3. Verificar instalación
flutter doctor

# 4. Instalar dependencias adicionales si es necesario
flutter doctor --android-licenses  # Para Android (si lo usas)
```

### Instalación usando Homebrew (alternativa)

```bash
brew install --cask flutter
```

---

## ✅ Solución 4: Verificar Permisos

Si Flutter está instalado pero tiene problemas de permisos:

```bash
# Encontrar Flutter
FLUTTER_PATH=$(which flutter || find ~ -name "flutter" -type f -path "*/bin/flutter" 2>/dev/null | head -1)

# Dar permisos de ejecución
chmod +x "$FLUTTER_PATH"

# Verificar permisos
ls -la "$FLUTTER_PATH"
```

---

## 🧪 Verificar que Funciona

Una vez que Flutter esté disponible, verifica:

```bash
# Ver versión
flutter --version

# Verificar instalación
flutter doctor

# Ver dispositivos disponibles
flutter devices
```

---

## 📝 Crear Alias (Opcional)

Si prefieres usar un comando más corto, puedes crear un alias en `~/.zshrc`:

```bash
# Añadir a ~/.zshrc
alias f="flutter"
alias fpg="flutter pub get"
alias fr="flutter run"
alias fa="flutter analyze"
```

Luego recarga: `source ~/.zshrc`

Y usa:
```bash
fpg  # en lugar de flutter pub get
fr   # en lugar de flutter run
```

---

## 🚀 Después de Resolver

Una vez que Flutter funcione:

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
flutter pub get
flutter analyze
flutter run
```

---

## 💡 Nota para macOS

Si usas macOS y planeas desarrollar para iOS, también necesitarás:
- Xcode (desde App Store)
- CocoaPods: `sudo gem install cocoapods`

Para Android:
- Android Studio
- Aceptar licencias: `flutter doctor --android-licenses`

---

## 📚 Referencias

- Instalación oficial: https://docs.flutter.dev/get-started/install
- Troubleshooting: https://docs.flutter.dev/get-started/install/macos

