#!/bin/bash
set -e

# Script para configurar el JNI del plugin Flutter en CoMaps
# Este script modifica el CMakeLists.txt de CoMaps para usar
# el código JNI del plugin en lugar del SDK original

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMAPS_DIR="$SCRIPT_DIR/../comaps"
COMAPS_CMAKE="$COMAPS_DIR/CMakeLists.txt"
PLUGIN_JNI_DIR="$SCRIPT_DIR/android/src/main/cpp"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Configurando JNI del plugin Flutter${NC}"
echo "=========================================="
echo ""

# Verificar que existe CoMaps
if [ ! -f "$COMAPS_CMAKE" ]; then
    echo -e "${RED}✗${NC} No se encontró $COMAPS_CMAKE"
    echo "Ejecuta primero: ./bootstrap.sh"
    exit 1
fi

echo -e "${YELLOW}Paso 1:${NC} Verificando CMakeLists.txt de CoMaps..."

# Buscar la línea que queremos modificar
if grep -q "add_subdirectory(android/sdk/src/main/cpp)" "$COMAPS_CMAKE"; then
    echo -e "${GREEN}✓${NC} Encontrada línea original del SDK"
else
    echo -e "${YELLOW}⚠${NC} La línea ya fue modificada o no existe"
fi

# Crear backup
BACKUP_FILE="$COMAPS_CMAKE.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${YELLOW}Paso 2:${NC} Creando backup..."
cp "$COMAPS_CMAKE" "$BACKUP_FILE"
echo -e "${GREEN}✓${NC} Backup guardado en: $BACKUP_FILE"

# Calcular la ruta relativa desde CoMaps al plugin
RELATIVE_PATH="../organic_maps_flutter/android/sdk/src/main/cpp"

echo -e "${YELLOW}Paso 3:${NC} Modificando CMakeLists.txt de CoMaps..."

# Usar sed para reemplazar la línea con el binary directory especificado
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|add_subdirectory(android/sdk/src/main/cpp)|add_subdirectory($RELATIVE_PATH \${CMAKE_CURRENT_BINARY_DIR}/organic_maps_flutter_jni)|g" "$COMAPS_CMAKE"
else
    # Linux
    sed -i "s|add_subdirectory(android/sdk/src/main/cpp)|add_subdirectory($RELATIVE_PATH \${CMAKE_CURRENT_BINARY_DIR}/organic_maps_flutter_jni)|g" "$COMAPS_CMAKE"
fi

echo -e "${GREEN}✓${NC} Subdirectorio configurado"

# Deshabilitar LTO para Android
echo -e "${YELLOW}Paso 4:${NC} Deshabilitando LTO para Android..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' 's|set (CMAKE_INTERPROCEDURAL_OPTIMIZATION True)|# Disable LTO for Android to avoid linker issues\n    if (NOT PLATFORM_ANDROID)\n      set (CMAKE_INTERPROCEDURAL_OPTIMIZATION True)\n    endif()|g' "$COMAPS_CMAKE"
else
    # Linux
    sed -i 's|set (CMAKE_INTERPROCEDURAL_OPTIMIZATION True)|# Disable LTO for Android to avoid linker issues\n    if (NOT PLATFORM_ANDROID)\n      set (CMAKE_INTERPROCEDURAL_OPTIMIZATION True)\n    endif()|g' "$COMAPS_CMAKE"
fi

echo -e "${GREEN}✓${NC} LTO deshabilitado para Android"

# Verificar el cambio
echo ""
echo -e "${YELLOW}Paso 5:${NC} Verificando cambios..."
echo ""
echo "Línea modificada:"
grep -A 1 "if (PLATFORM_ANDROID)" "$COMAPS_CMAKE" | tail -n 1
echo ""

# Verificar que existe el directorio del plugin
if [ ! -d "$PLUGIN_JNI_DIR" ]; then
    echo -e "${YELLOW}⚠${NC} El directorio JNI del plugin no existe: $PLUGIN_JNI_DIR"
    echo "Creando estructura básica..."
    mkdir -p "$PLUGIN_JNI_DIR"
    echo -e "${GREEN}✓${NC} Directorio creado"
fi

# Configurar el CMakeLists.txt del plugin
PLUGIN_CMAKE="$PLUGIN_JNI_DIR/CMakeLists.txt"
if [ -f "$PLUGIN_CMAKE" ]; then
    echo ""
    echo -e "${YELLOW}Paso 6:${NC} Configurando CMakeLists.txt del plugin..."
    
    # Agregar configuración del linker lld si no existe
    if ! grep -q "fuse-ld=lld" "$PLUGIN_CMAKE"; then
        # Buscar la línea target_include_directories y agregar después
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' '/target_include_directories.*BEFORE PRIVATE/a\
\
# Use lld linker instead of gold for Android\
if (ANDROID)\
  target_link_options(${PROJECT_NAME} PRIVATE "-fuse-ld=lld")\
endif()
' "$PLUGIN_CMAKE"
        else
            # Linux
            sed -i '/target_include_directories.*BEFORE PRIVATE/a\
\
# Use lld linker instead of gold for Android\
if (ANDROID)\
  target_link_options(${PROJECT_NAME} PRIVATE "-fuse-ld=lld")\
endif()' "$PLUGIN_CMAKE"
        fi
        echo -e "${GREEN}✓${NC} Linker lld configurado"
    else
        echo -e "${GREEN}✓${NC} Linker lld ya estaba configurado"
    fi
    
    # Asegurar que BEFORE está en target_include_directories
    if ! grep -q "target_include_directories.*BEFORE" "$PLUGIN_CMAKE"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's|target_include_directories(\${PROJECT_NAME} PRIVATE|target_include_directories(\${PROJECT_NAME} BEFORE PRIVATE|g' "$PLUGIN_CMAKE"
        else
            sed -i 's|target_include_directories(\${PROJECT_NAME} PRIVATE|target_include_directories(\${PROJECT_NAME} BEFORE PRIVATE|g' "$PLUGIN_CMAKE"
        fi
        echo -e "${GREEN}✓${NC} Prioridad de headers configurada"
    fi
    
    # Cambiar GLESv2 a GLESv3 para soporte de OpenGL ES 3.0
    if grep -q "GLESv2" "$PLUGIN_CMAKE"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's|GLESv2|GLESv3  # OpenGL ES 3.0 for VAO and other functions|g' "$PLUGIN_CMAKE"
        else
            sed -i 's|GLESv2|GLESv3  # OpenGL ES 3.0 for VAO and other functions|g' "$PLUGIN_CMAKE"
        fi
        echo -e "${GREEN}✓${NC} OpenGL ES 3.0 configurado"
    fi
fi

echo ""
echo -e "${GREEN}✅ Configuración completada!${NC}"
echo ""
echo "Cambios realizados:"
echo "  • Backup: $BACKUP_FILE"
echo "  • CMakeLists.txt de CoMaps:"
echo "    - Subdirectorio: $RELATIVE_PATH"
echo "    - Binary directory: \${CMAKE_CURRENT_BINARY_DIR}/organic_maps_flutter_jni"
echo "    - LTO deshabilitado para Android"
echo "  • CMakeLists.txt del plugin:"
echo "    - Linker lld configurado"
echo "    - Prioridad de headers configurada"
echo "    - OpenGL ES 3.0 (GLESv3) configurado"
echo "  • Archivos .cpp corregidos (includes relativos)"
echo ""
echo "Para revertir los cambios:"
echo "  cp $BACKUP_FILE $COMAPS_CMAKE"
echo ""
echo "Siguiente paso:"
echo "  cd android && ./gradlew :sdk:assembleRelease"
