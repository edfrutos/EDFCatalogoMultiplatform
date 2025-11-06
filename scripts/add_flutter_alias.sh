#!/bin/bash

# Script para agregar automáticamente el alias/función de Flutter con soporte Linux
# Uso: ./scripts/add_flutter_alias.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$PROJECT_DIR/scripts/flutter_run_with_linux.sh"

# Detectar el shell actual
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
    SHELL_NAME="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
    SHELL_NAME="bash"
else
    echo "⚠️  No se pudo detectar el shell. Usando ~/.zshrc por defecto."
    SHELL_RC="$HOME/.zshrc"
    SHELL_NAME="zsh"
fi

echo "🔧 Agregando función Flutter con soporte Linux a $SHELL_RC"
echo ""

# Verificar si ya existe la función
if grep -q "# Función para flutter con soporte Linux" "$SHELL_RC" 2>/dev/null; then
    echo "⚠️  La función ya existe en $SHELL_RC"
    echo "   ¿Deseas reemplazarla? (s/n)"
    read -r response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        echo "❌ Cancelado."
        exit 0
    fi
    # Eliminar la función existente
    sed -i.bak '/# Función para flutter con soporte Linux/,/^}$/d' "$SHELL_RC"
fi

# Crear backup
cp "$SHELL_RC" "${SHELL_RC}.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

# Agregar la función
cat >> "$SHELL_RC" << EOF

# Función para flutter con soporte Linux
# Agregado automáticamente por EDFCatalogoMultiplatform
flutter() {
    local PROJECT_DIR="$PROJECT_DIR"
    local WRAPPER="$WRAPPER"
    
    # Si el comando es 'run' o 'devices', usar el wrapper
    # También capturar 'run -d linux' o cualquier variante
    if [[ "\$1" == "run" ]] || [[ "\$1" == "devices" ]] || [[ "\$*" == *"-d linux"* ]] || [[ "\$*" == *"--device-id linux"* ]]; then
        cd "\$PROJECT_DIR" && "\$WRAPPER" "\$@"
    else
        # Para otros comandos, usar flutter normalmente
        command flutter "\$@"
    fi
}
EOF

echo "✅ Función agregada a $SHELL_RC"
echo ""
echo "📋 Para aplicar los cambios, ejecuta:"
echo "   source $SHELL_RC"
echo ""
echo "🎯 Ahora puedes usar:"
echo "   flutter run        # Muestra Linux como opción"
echo "   flutter devices    # Muestra Linux en la lista"
echo "   flutter build      # Funciona normalmente"

