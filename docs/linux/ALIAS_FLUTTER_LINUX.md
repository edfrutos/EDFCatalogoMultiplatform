# 🐧 Usar Linux con Flutter Run

## Opción 1: Crear función en ~/.zshrc (Recomendado para zsh)

Agrega esto a tu `~/.zshrc`:

```bash
# Función para flutter con soporte Linux
flutter() {
    local PROJECT_DIR="/Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform"
    local WRAPPER="$PROJECT_DIR/scripts/flutter_run_with_linux.sh"
    
    # Si el comando es 'run' o 'devices', usar el wrapper
    # También capturar 'run -d linux' o cualquier variante
    if [[ "$1" == "run" ]] || [[ "$1" == "devices" ]] || [[ "$*" == *"-d linux"* ]] || [[ "$*" == *"--device-id linux"* ]]; then
        cd "$PROJECT_DIR" && "$WRAPPER" "$@"
    else
        # Para otros comandos, usar flutter normalmente
        command flutter "$@"
    fi
}
```

Luego recarga tu shell:
```bash
source ~/.zshrc
```

Ahora puedes usar:
```bash
flutter run        # Muestra Linux como opción
flutter devices    # Muestra Linux en la lista
flutter build      # Funciona normalmente
```

## Opción 2: Crear función en ~/.bashrc (Para bash)

Agrega esto a tu `~/.bashrc`:

```bash
# Función para flutter con soporte Linux
flutter() {
    local PROJECT_DIR="/Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform"
    local WRAPPER="$PROJECT_DIR/scripts/flutter_run_with_linux.sh"
    
    # Si el comando es 'run' o 'devices', usar el wrapper
    # También capturar 'run -d linux' o cualquier variante
    if [[ "$1" == "run" ]] || [[ "$1" == "devices" ]] || [[ "$*" == *"-d linux"* ]] || [[ "$*" == *"--device-id linux"* ]]; then
        cd "$PROJECT_DIR" && "$WRAPPER" "$@"
    else
        # Para otros comandos, usar flutter normalmente
        command flutter "$@"
    fi
}
```

Luego recarga tu shell:
```bash
source ~/.bashrc
```

## Opción 3: Alias simple (Alternativa)

Si prefieres un alias en lugar de una función, agrega a `~/.zshrc` o `~/.bashrc`:

```bash
# Alias para flutter run con soporte Linux
alias flutter-run='cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform && ./scripts/flutter_run_with_linux.sh run'
alias flutter-devices='cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform && ./scripts/flutter_run_with_linux.sh devices'
```

Luego usa:
```bash
flutter-run        # Ejecuta con menú que incluye Linux
flutter-devices    # Muestra dispositivos incluyendo Linux
flutter build      # Funciona normalmente (sin alias)
```

## Opción 4: Usar el wrapper directamente

```bash
cd /Users/edefrutos/__Proyectos/EDFCatalogoMultiplatform
./scripts/flutter_run_with_linux.sh run
```

## Nota

Linux no aparece en `flutter devices` nativo porque Flutter en macOS no puede ejecutar aplicaciones Linux directamente. El wrapper agrega Linux como opción virtual que usa Docker automáticamente.

