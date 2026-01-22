#!/bin/bash

# Script para actualizar la versión de Gradle en los plugins de Flutter
# Este script actualiza el gradle-wrapper.properties de los plugins que usan Gradle 8.10 a 8.13

echo "🔧 Actualizando versiones de Gradle en plugins..."

# Buscar todos los archivos gradle-wrapper.properties en .pub-cache que usen Gradle 8.10
find ~/.pub-cache/hosted/pub.dev -name "gradle-wrapper.properties" -type f 2>/dev/null | while read file; do
    # Verificar si el archivo usa Gradle 8.10
    if grep -q "gradle-8.10" "$file" 2>/dev/null; then
        echo "📝 Actualizando: $file"
        # Actualizar a Gradle 8.13
        sed -i '' 's/gradle-8.10-bin.zip/gradle-8.13-bin.zip/g' "$file"
        echo "   ✅ Actualizado a Gradle 8.13"
    fi
done

echo "✅ Proceso completado"

