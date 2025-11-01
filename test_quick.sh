#!/bin/bash

# Script rápido para verificar que todo esté listo para probar

echo "🔍 Verificando estado del proyecto..."
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: No se encuentra pubspec.yaml"
    echo "   Asegúrate de estar en el directorio del proyecto Flutter"
    exit 1
fi

echo "✅ pubspec.yaml encontrado"

# Verificar Flutter
if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter no está en el PATH"
    echo "   Instala Flutter o añádelo al PATH"
else
    echo "✅ Flutter instalado: $(flutter --version | head -n 1)"
fi

# Verificar .env
if [ -f ".env" ]; then
    echo "✅ Archivo .env encontrado"
else
    echo "⚠️  Archivo .env no encontrado"
    echo "   Crea un archivo .env con las configuraciones necesarias"
fi

# Verificar dependencias instaladas
if [ -d "build" ] || [ -f "pubspec.lock" ]; then
    echo "✅ Dependencias parecen estar instaladas (pubspec.lock encontrado)"
else
    echo "⚠️  Ejecuta 'flutter pub get' para instalar dependencias"
fi

# Verificar archivos clave
FILES=(
    "lib/main.dart"
    "lib/services/mongo_service.dart"
    "lib/services/sync_service.dart"
    "lib/services/local_storage_service.dart"
    "lib/utils/validators.dart"
)

MISSING=0
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - NO ENCONTRADO"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
if [ $MISSING -eq 0 ]; then
    echo "✅ Todos los archivos principales están presentes"
    echo ""
    echo "🚀 Siguiente paso:"
    echo "   flutter pub get && flutter run"
else
    echo "⚠️  Faltan $MISSING archivo(s) importante(s)"
    echo "   Revisa el proyecto antes de continuar"
fi

echo ""
echo "📚 Documentación disponible:"
echo "   • INSTRUCCIONES_PRUEBAS.md - Guía paso a paso"
echo "   • CHECKLIST_PRUEBAS.md - Checklist interactivo"
echo "   • GUIA_PRUEBAS.md - Guía técnica completa"

