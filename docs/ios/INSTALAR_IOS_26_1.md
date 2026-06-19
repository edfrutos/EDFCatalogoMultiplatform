# 📱 Instalar iOS 26.1 Runtime en Xcode

## 🔍 Problema Identificado

Xcode está buscando iOS 26.1 pero no está instalado. Tu simulador actual usa iOS 18.5, pero Xcode necesita iOS 26.1 para algunos dispositivos.

## ✅ Solución: Instalar iOS 26.1 Runtime

### Método 1: Desde Xcode (RECOMENDADO)

1. **Abre Xcode** (si no está abierto)

2. **Ve a Xcode Settings:**
   - **Xcode** → **Settings** (o **Preferences** si usas versión anterior)
   - O presiona `Cmd + ,` (comando + coma)

3. **Ve a la pestaña "Platforms" o "Components":**
   - En versiones recientes: pestaña **"Platforms"**
   - En versiones anteriores: pestaña **"Components"** o **"Locations"**

4. **Busca iOS 26.1:**
   - Deberías ver una lista de plataformas disponibles
   - Busca **"iOS 26.1"** o **"iOS Simulator 26.1"**
   - Si aparece, debería tener un botón **"Get"** o **"Download"** junto a él

5. **Descarga iOS 26.1:**
   - Haz clic en el botón **"Get"** o **"Download"**
   - Esto descargará e instalará el runtime de iOS 26.1
   - El proceso puede tardar varios minutos (varios GB)

6. **Espera a que termine la descarga:**
   - Verás una barra de progreso
   - No cierres Xcode durante la descarga

### Método 2: Desde la Terminal (ALTERNATIVA)

Si prefieres usar la terminal:

```bash
# Listar runtimes disponibles para descargar
xcodebuild -downloadPlatform iOS

# O instalar específicamente
xcodebuild -downloadPlatform iOS -version 26.1
```

**Nota:** Este método puede no estar disponible en todas las versiones de Xcode.

## 🔄 Alternativa: Usar un Simulador Compatible

Si no quieres esperar la descarga (puede ser grande), puedes usar un simulador que ya tengas:

### Opción A: Usar el Simulador con iOS 18.5

Ya tienes iOS 18.5 instalado. Podemos crear/usar un simulador con esa versión:

1. En Xcode: **Window** → **Devices and Simulators**
2. Pestaña **"Simulators"**
3. Crea un nuevo simulador con iOS 18.5
4. Úsalo en lugar del que requiere iOS 26.1

### Opción B: Usar Flutter con el Simulador Disponible

Flutter puede funcionar con iOS 18.5. El problema es que Xcode está configurado para buscar iOS 26.1.

## 📝 Pasos Recomendados

### Opción 1: Instalar iOS 26.1 (SI TIENES TIEMPO)
1. Ve a Xcode → Settings → Platforms
2. Descarga iOS 26.1
3. Espera a que termine (puede tardar 10-30 minutos dependiendo de tu conexión)
4. Una vez instalado, vuelve a intentar ejecutar la app

### Opción 2: Usar iOS 18.5 (MÁS RÁPIDO)
1. Crea un simulador con iOS 18.5 (ya lo tienes instalado)
2. Úsalo desde Xcode o Flutter
3. Funcionará perfectamente para desarrollo

## 🚀 Recomendación Inmediata

**Para continuar AHORA sin esperar la descarga:**

1. En Xcode, ve a **Window** → **Devices and Simulators**
2. Pestaña **"Simulators"**
3. Busca un simulador que use **iOS 18.5**
4. Si no existe, créalo:
   - Clic en **"+"**
   - Device: iPhone 16 Pro
   - OS: iOS 18.5
   - Name: iPhone 16 Pro iOS 18.5
5. Haz clic en **"Boot"** para iniciarlo
6. En Xcode, selecciona este simulador en el dropdown
7. Presiona `Cmd + R` para ejecutar

## ⚠️ Nota Importante

El runtime de iOS 26.1 puede ser grande (varios GB). Si tienes conexión lenta o espacio limitado, es mejor usar iOS 18.5 que ya tienes instalado.

