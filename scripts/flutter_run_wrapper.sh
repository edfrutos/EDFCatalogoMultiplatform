#!/bin/bash

# Wrapper para flutter run que detecta si se quiere ejecutar en Linux
# Uso: ./scripts/flutter_run_wrapper.sh [opciones]
# O crear un alias: alias flutter='./scripts/flutter_run_wrapper.sh'

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Si se especifica -d linux o --device-id linux, usar el script de Docker
if [[ "$*" == *"-d linux"* ]] || [[ "$*" == *"--device-id linux"* ]] || [[ "$*" == *"-d=linux"* ]]; then
    echo "🐧 Detectado Linux como dispositivo, usando Docker..."
    exec "$SCRIPT_DIR/flutter_run_linux.sh" "${@//-d linux/}" "${@//--device-id linux/}" "${@//-d=linux/}"
fi

# Si no, ejecutar flutter run normalmente
cd "$PROJECT_DIR"
exec flutter "$@"

