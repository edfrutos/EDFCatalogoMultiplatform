#!/bin/bash

# Script para sincronizar la versión de Android Gradle Plugin en los plugins de Flutter
# Este script actualiza el build.gradle de los plugins para usar la misma versión de AGP que el proyecto

AGP_VERSION="8.7.3"
PLUGIN_NAME="flutter_plugin_android_lifecycle"

echo "🔧 Sincronizando versión de Android Gradle Plugin a $AGP_VERSION..."

# Buscar todos los archivos build.gradle del plugin (excluir example)
PLUGIN_BUILD_GRADLES=$(find ~/.pub-cache/hosted/pub.dev -path "*/${PLUGIN_NAME}-*/android/build.gradle" -type f ! -path "*/example/*" 2>/dev/null)

if [ -z "$PLUGIN_BUILD_GRADLES" ]; then
    echo "⚠️ No se encontró el plugin $PLUGIN_NAME"
    exit 1
fi

# Actualizar todos los archivos encontrados
echo "$PLUGIN_BUILD_GRADLES" | while read -r PLUGIN_BUILD_GRADLE; do
    echo "📝 Actualizando: $PLUGIN_BUILD_GRADLE"
    
    # Actualizar la versión de Android Gradle Plugin
    if grep -q "classpath 'com.android.tools.build:gradle:" "$PLUGIN_BUILD_GRADLE" 2>/dev/null; then
        # macOS usa sed -i '', Linux usa sed -i
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/classpath 'com.android.tools.build:gradle:[^']*'/classpath 'com.android.tools.build:gradle:${AGP_VERSION}'/g" "$PLUGIN_BUILD_GRADLE"
        else
            sed -i "s/classpath 'com.android.tools.build:gradle:[^']*'/classpath 'com.android.tools.build:gradle:${AGP_VERSION}'/g" "$PLUGIN_BUILD_GRADLE"
        fi
        echo "   ✅ Actualizado a Android Gradle Plugin $AGP_VERSION"
    else
        echo "   ⚠️ No se encontró la línea classpath en el archivo"
    fi
done

echo "✅ Proceso completado"

