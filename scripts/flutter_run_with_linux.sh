#!/bin/bash

# Wrapper para flutter run que incluye Linux como opción
# Uso: ./scripts/flutter_run_with_linux.sh [opciones]
# 
# Este script intercepta 'flutter run' y agrega Linux como opción disponible
# Cuando se selecciona Linux, automáticamente usa Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Si se especifica -d linux o --device-id linux, usar Docker
if [[ "$*" == *"-d linux"* ]] || [[ "$*" == *"--device-id linux"* ]] || [[ "$*" == *"-d=linux"* ]] || [[ "$*" == *"-d linux-docker"* ]]; then
    echo "🐧 Detectado Linux, usando Docker..."
    # Remover las opciones de dispositivo Linux y "run" de los argumentos
    # Si los argumentos son "run -d linux", solo queremos pasar los argumentos adicionales (como --release, --debug, etc.)
    ARGS_WITHOUT_LINUX=$(echo "$@" | sed 's/run//g' | sed 's/-d linux//g' | sed 's/--device-id linux//g' | sed 's/-d=linux//g' | sed 's/-d linux-docker//g' | sed 's/  */ /g' | xargs)
    # Si no hay argumentos adicionales, usar --debug por defecto
    if [ -z "$ARGS_WITHOUT_LINUX" ]; then
        ARGS_WITHOUT_LINUX="--debug"
    fi
    exec "$SCRIPT_DIR/flutter_run_linux.sh" $ARGS_WITHOUT_LINUX
fi

# Si se ejecuta 'flutter run' sin argumentos, mostrar dispositivos incluyendo Linux
if [ $# -eq 0 ] || [[ "$*" == "run" ]]; then
    echo "Connected devices:"
    flutter devices 2>/dev/null | tail -n +2
    echo "  Linux (docker)                  • linux-docker                    • linux            • Linux via Docker (requires Docker Desktop)"
    echo ""
    echo "No wireless devices were found."
    echo ""
    
    # Obtener dispositivos y sus IDs
    DEVICE_LIST=$(flutter devices 2>/dev/null | grep -E "^\s+\w" | sed 's/^[[:space:]]*//' || echo "")
    
    # Crear arrays para dispositivos e IDs
    declare -a DEVICE_NAMES
    declare -a DEVICE_IDS
    INDEX=1
    
    # Parsear dispositivos de Flutter
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # Extraer el ID del dispositivo (primera parte después del primer •)
            # Formato: "Nombre • ID • tipo • descripción"
            DEVICE_ID=$(echo "$line" | awk -F'•' '{print $2}' | xargs)
            DEVICE_NAME=$(echo "$line" | awk -F'•' '{print $1}' | xargs)
            
            if [ -n "$DEVICE_ID" ] && [ -n "$DEVICE_NAME" ]; then
                DEVICE_NAMES[$INDEX]="$DEVICE_NAME"
                DEVICE_IDS[$INDEX]="$DEVICE_ID"
                echo "[$INDEX]: $DEVICE_NAME ($DEVICE_ID)"
                INDEX=$((INDEX + 1))
            fi
        fi
    done <<< "$DEVICE_LIST"
    
    # Agregar Linux como última opción
    LINUX_INDEX=$INDEX
    echo "[$LINUX_INDEX]: Linux (docker) (linux-docker)"
    
    echo "Please choose one (or \"q\" to quit): "
    read -r choice
    
    # Si la opción seleccionada es Linux
    if [ "$choice" = "$LINUX_INDEX" ]; then
        echo "🐧 Iniciando Linux en Docker..."
        exec "$SCRIPT_DIR/flutter_run_linux.sh"
    fi
    
    # Si es un número válido, usar ese dispositivo
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$LINUX_INDEX" ]; then
        SELECTED_ID="${DEVICE_IDS[$choice]}"
        exec flutter run -d "$SELECTED_ID"
    fi
    
    # Si no es válido, ejecutar flutter run normalmente (Flutter mostrará su propio menú)
    exec flutter run
fi

# Si se ejecuta 'flutter devices', agregar Linux
if [[ "$*" == "devices" ]]; then
    flutter devices 2>/dev/null
    echo "  Linux (docker)                  • linux-docker                    • linux            • Linux via Docker (requires Docker Desktop)"
    exit 0
fi

# Para cualquier otro comando, ejecutar flutter normalmente
exec flutter "$@"

