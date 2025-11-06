#!/bin/bash

# Script que muestra los dispositivos de Flutter incluyendo Linux (vía Docker)
# Uso: ./scripts/flutter_devices_with_linux.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "Found devices:"
flutter devices 2>/dev/null | tail -n +2

# Agregar Linux como opción
echo "  Linux (docker)                  • linux-docker                    • linux            • Linux via Docker (requires Docker Desktop)"

