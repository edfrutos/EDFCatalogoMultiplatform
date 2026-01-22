# 🐧 Ejecutar Flutter en Linux

## Opción 0: Ejecutar directamente en Linux (entorno nativo)

Si ya estás trabajando **desde un equipo Linux**, no necesitas Docker ni scripts adicionales:

```bash
flutter pub get
flutter run -d linux        # Desarrollo interactivo
flutter build linux --release   # Build de producción
```

La aplicación se ejecutará usando los binarios nativos de Flutter y guardará los backups en `~/Downloads` automáticamente.

---

## Opción 1: Usar el wrapper que incluye Linux (Recomendado desde macOS)

```bash
./scripts/flutter_run_with_linux.sh
```

Este script muestra todos los dispositivos disponibles **incluyendo Linux**, y puedes seleccionarlo desde el menú interactivo.

## Opción 2: Usar el script dedicado directamente

```bash
./scripts/flutter_run_linux.sh [opciones]
```

Ejemplos:
```bash
# Modo debug (por defecto)
./scripts/flutter_run_linux.sh

# Modo release
./scripts/flutter_run_linux.sh --release

# Con hot reload
./scripts/flutter_run_linux.sh --debug

# Especificar dispositivo directamente
./scripts/flutter_run_linux.sh -d linux
```

## Opción 2: Usar VNC (GUI completa)

```bash
./scripts/ejecutar_linux_vnc.sh
```

Luego conéctate con un cliente VNC a `localhost:5900`.

## Opción 3: Compilar para Linux

```bash
# Compilar en Docker
docker-compose -f docker/docker-compose.linux-test.yml run --rm flutter build linux --release

# El ejecutable estará en: build/linux/arm64/release/bundle/
```

## Notas

- Linux no aparece como dispositivo en `flutter devices` en macOS porque requiere Docker
- El script `flutter_run_linux.sh` maneja automáticamente el contenedor Docker
- Asegúrate de tener Docker Desktop corriendo antes de ejecutar

