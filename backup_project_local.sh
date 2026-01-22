#!/bin/bash

# Script para crear backup del proyecto EDFCatalogoMultiplatform
# Incluye todos los archivos del proyecto, incluyendo archivos sensibles (.env, credenciales, etc.)

set -e  # Salir si hay algún error

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Rutas genéricas (multiplataforma)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Permitir sobrescritura mediante variables de entorno
PROJECT_PATH="${EDF_PROJECT_DIR:-${PROJECT_DIR:-}}"
if [ -z "$PROJECT_PATH" ]; then
    PROJECT_PATH="$SCRIPT_DIR"
    SEARCH_DIR="$SCRIPT_DIR"
    for _ in $(seq 1 10); do
        if [ -f "${SEARCH_DIR}/pubspec.yaml" ]; then
            PROJECT_PATH="$SEARCH_DIR"
            break
        fi
        PARENT_DIR="$(dirname "$SEARCH_DIR")"
        if [ "$PARENT_DIR" = "$SEARCH_DIR" ]; then
            break
        fi
        SEARCH_DIR="$PARENT_DIR"
    done
fi

if [ ! -d "$PROJECT_PATH" ] && [ -n "$HOME" ]; then
    for candidate in \
        "$HOME/EDFCatalogoMultiplatform" \
        "$HOME/proyectos/EDFCatalogoMultiplatform" \
        "$HOME/__Proyectos/EDFCatalogoMultiplatform"; do
        if [ -d "$candidate" ]; then
            PROJECT_PATH="$candidate"
            break
        fi
    done
fi

BACKUP_BASE_PATH="${EDF_BACKUP_DIR:-${EDF_BACKUPS_DIR:-}}"
if [ -z "$BACKUP_BASE_PATH" ]; then
    if [ -n "$HOME" ]; then
        BACKUP_BASE_PATH="$HOME/EDFCatalogoBackups"
    else
        BACKUP_BASE_PATH="${SCRIPT_DIR}/EDFCatalogoBackups"
    fi
fi

BACKUP_FOLDER="project_backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="project_backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_BASE_PATH}/${BACKUP_FOLDER}/${BACKUP_NAME}"

# Verificar que el directorio del proyecto existe
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ Error: El directorio del proyecto no existe: $PROJECT_PATH${NC}"
    exit 1
fi

# Crear directorios de backup si no existen
mkdir -p "${BACKUP_BASE_PATH}/${BACKUP_FOLDER}"

echo -e "${GREEN}📦 Iniciando backup del proyecto...${NC}"
echo -e "   Origen: ${PROJECT_PATH}"
echo -e "   Destino: ${BACKUP_PATH}"
echo ""

# Crear directorio de backup
mkdir -p "${BACKUP_PATH}"

# Contador de archivos
FILES_COPIED=0
TOTAL_SIZE=0

# Función para obtener el tamaño de un archivo
get_file_size() {
    if [ "$(uname)" == "Darwin" ]; then
        stat -f%z "$1" 2>/dev/null || echo 0
    else
        stat -c%s "$1" 2>/dev/null || echo 0
    fi
}

# Función para verificar si un directorio debe ser excluido
should_exclude_dir() {
    local dir_name=$(basename "$1")
    case "$dir_name" in
        build|.dart_tool|.flutter-plugins|.flutter-plugins-dependencies|.git|node_modules|coverage|.idea|.vscode)
            return 0  # Excluir
            ;;
        *)
            return 1  # No excluir
            ;;
    esac
}

# Función para copiar archivos recursivamente excluyendo solo build/compilación
copy_with_exclusions() {
    local source_dir="$1"
    local dest_dir="$2"
    local relative_path="${3:-}"
    
    # Copiar archivos en el directorio actual
    for item in "$source_dir"/*; do
        # Verificar si el item existe (puede no haber archivos)
        [ -e "$item" ] || continue
        
        local item_name=$(basename "$item")
        local item_relative="${relative_path:+$relative_path/}$item_name"
        
        # Omitir archivos ocultos del sistema (excepto .env y otros archivos importantes)
        if [[ "$item_name" == .DS_Store ]] || [[ "$item_name" == ._.* ]]; then
            continue
        fi
        
        # Si es un directorio, verificar si debe ser excluido
        if [ -d "$item" ]; then
            if should_exclude_dir "$item"; then
                echo -e "${YELLOW}   ⏭️  Omitiendo directorio: $item_name${NC}"
                continue
            fi
            
            # Crear directorio en destino
            mkdir -p "${dest_dir}/${item_name}"
            
            # Copiar recursivamente
            copy_with_exclusions "$item" "${dest_dir}/${item_name}" "$item_relative"
        else
            # Es un archivo, copiarlo
            # Omitir solo archivos temporales/log muy específicos
            if [[ "$item_name" == *.log ]] || [[ "$item_name" == *.tmp ]] || [[ "$item_name" == *.bak ]] || [[ "$item_name" == *.swp ]]; then
                continue
            fi
            
            cp "$item" "${dest_dir}/${item_name}"
            local file_size=$(get_file_size "$item")
            TOTAL_SIZE=$((TOTAL_SIZE + file_size))
            FILES_COPIED=$((FILES_COPIED + 1))
            
            if [ $((FILES_COPIED % 100)) -eq 0 ]; then
                echo -e "${GREEN}   📄 Archivos copiados: $FILES_COPIED...${NC}"
            fi
        fi
    done
}

# Copiar archivos del proyecto
echo -e "${GREEN}📋 Copiando archivos...${NC}"
copy_with_exclusions "$PROJECT_PATH" "$BACKUP_PATH"

# Calcular tamaño formateado
SIZE_MB=$(echo "scale=2; $TOTAL_SIZE / 1024 / 1024" | bc)

echo ""
echo -e "${GREEN}✅ Backup del proyecto completado${NC}"
echo -e "   Archivos copiados: ${FILES_COPIED}"
echo -e "   Tamaño total: ${SIZE_MB} MB"
echo -e "   Ubicación: ${BACKUP_PATH}"

# Crear archivo ZIP del backup
echo ""
echo -e "${GREEN}📦 Comprimiendo backup en ZIP...${NC}"
ZIP_PATH="${BACKUP_PATH}.zip"

# Verificar si zip está disponible
if command -v zip &> /dev/null; then
    # Crear ZIP excluyendo el propio script si está en el directorio
    cd "$(dirname "$BACKUP_PATH")"
    ZIP_NAME=$(basename "$ZIP_PATH")
    BACKUP_DIR_NAME=$(basename "$BACKUP_PATH")
    
    if zip -r "$ZIP_NAME" "$BACKUP_DIR_NAME" -q; then
        ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
        echo -e "${GREEN}✅ ZIP creado: ${ZIP_PATH}${NC}"
        echo -e "   Tamaño del ZIP: ${ZIP_SIZE}"
    else
        echo -e "${YELLOW}⚠️  Error al crear el ZIP. Continuando sin comprimir...${NC}"
        ZIP_PATH=""
    fi
    cd - > /dev/null
else
    echo -e "${YELLOW}⚠️  Comando 'zip' no encontrado. Instálalo con: brew install zip${NC}"
    echo -e "${YELLOW}   Continuando sin comprimir...${NC}"
    ZIP_PATH=""
fi

echo ""
echo -e "${GREEN}💾 Nota: Los archivos sensibles (.env, credenciales, etc.) están incluidos en el backup${NC}"

# Opción para abrir Finder (macOS)
if [ "$(uname)" == "Darwin" ]; then
    read -p "¿Abrir ubicación del backup en Finder? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        if [ -n "$ZIP_PATH" ] && [ -f "$ZIP_PATH" ]; then
            open "$(dirname "$ZIP_PATH")"
        else
            open "${BACKUP_PATH}"
        fi
    fi
fi

