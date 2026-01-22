# 🚀 Guía Rápida: Ejecutar en Android Studio

## ⚡ Pasos Rápidos (5 minutos)

### 1️⃣ Abrir el Proyecto
```
Android Studio → File → Open → Seleccionar carpeta del proyecto
```

### 2️⃣ Sincronizar Gradle
```
File → Sync Project with Gradle Files
```
⏱️ Espera 2-3 minutos

### 3️⃣ Iniciar Emulador
```
Tools → Device Manager → ▶️ (Iniciar emulador)
```
⏱️ Espera 1-2 minutos

### 4️⃣ Ejecutar Aplicación
```
▶️ (Run) o Shift + F10
```
⏱️ Primera compilación: 3-5 minutos

---

## 📋 Checklist Pre-Ejecución

Antes de ejecutar, verifica:

- [ ] **Proyecto abierto** en Android Studio
- [ ] **Gradle sincronizado** (sin errores)
- [ ] **Emulador iniciado** (visible en Device Manager)
- [ ] **Java 17+ configurado** en Gradle settings
- [ ] **Script ejecutado** (opcional): `./android/sync_gradle_version.sh`

---

## 🎯 Ubicaciones Importantes en Android Studio

### Barra de Herramientas Superior
```
[Dropdown de dispositivos] [▶️ Run] [🔄 Hot Reload] [⏹️ Stop]
```

### Paneles Inferiores
- **Build** - Progreso de compilación
- **Run** - Logs de Flutter
- **Logcat** - Logs de Android
- **Terminal** - Terminal integrada

### Menús Principales
- **File** → **Sync Project with Gradle Files**
- **Tools** → **Device Manager**
- **Run** → **Run 'app'**
- **Build** → **Clean Project**

---

## 🔧 Configuración Rápida

### Verificar JDK
```
File → Settings → Build, Execution, Deployment → Build Tools → Gradle
Gradle JDK: JDK 17 o superior
```

### Verificar Android SDK
```
File → Settings → Appearance & Behavior → System Settings → Android SDK
Android SDK Platform: 33 o superior
```

---

## ⚠️ Si Algo Falla

### Error: "Gradle sync failed"
```bash
# En Terminal integrada (desde la raíz del proyecto):
./android/sync_gradle_version.sh

# Si estás en el directorio android/, usa:
./sync_gradle_version.sh

# Luego en Android Studio:
File → Sync Project with Gradle Files
```

### Error: "No devices found"
```
Tools → Device Manager → ▶️ (Iniciar emulador)
Esperar a que el emulador termine de cargar
```

### Error: "Build failed"
```bash
# En Terminal integrada:
flutter clean
flutter pub get
File → Sync Project with Gradle Files
```

---

## 🎓 Comandos Útiles

### Hot Reload
- **Guardar cambios** → **🔄 Hot Reload** o `Ctrl + \`
- Recarga cambios sin reiniciar la aplicación

### Hot Restart
- **🔄 Hot Restart** o `Ctrl + Shift + \`
- Reinicia la aplicación manteniendo el estado

### Debug
- **🐛 Debug 'app'** o `Shift + F9`
- Ejecuta en modo debug con breakpoints

---

## 📱 Verificar que Funciona

### Logs Esperados
```
✅ Variables de entorno cargadas desde assets para Android
📋 Variables cargadas: X
✅ Variables cargadas: MONGO_URI ✅ Cargada
```

### En el Emulador
- La aplicación se abre automáticamente
- Muestra la pantalla de inicio/login
- No hay errores visibles

---

## 📚 Documentación Completa

Para más detalles, consulta:
- **`COMO_EJECUTAR_ANDROID_STUDIO.md`** - Guía completa paso a paso
- **`INSTRUCCIONES_EJECUTAR_ANDROID.md`** - Instrucciones generales
- **`GUIA_PRUEBAS_ANDROID.md`** - Checklist de pruebas

---

## 🎯 Siguiente Paso

Una vez que la aplicación esté ejecutándose:
1. Verifica que las variables de entorno se cargan
2. Prueba la conexión a MongoDB
3. Prueba la funcionalidad de archivos
4. Consulta `GUIA_PRUEBAS_ANDROID.md` para más pruebas

---

**¡Listo para ejecutar!** 🚀

