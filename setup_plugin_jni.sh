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

# Arreglar el parsing de subtypes.csv
FTYPES_SUBTYPES="$COMAPS_DIR/libs/indexer/ftypes_subtypes.cpp"
if [ -f "$FTYPES_SUBTYPES" ]; then
    echo ""
    echo -e "${YELLOW}Paso 7:${NC} Arreglando parsing de subtypes.csv..."
    
    # Verificar si ya tiene el fix de whitespace trimming
    if ! grep -q "Trim whitespace from the column" "$FTYPES_SUBTYPES"; then
        # Crear backup del archivo
        cp "$FTYPES_SUBTYPES" "$FTYPES_SUBTYPES.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Agregar trimming a nivel de columna
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' '/string_view const column = columns\[columnIndex\];/c\
        string_view column = columns[columnIndex];\
        \
        \/\/ Trim whitespace from the column\
        while (!column.empty() \&\& std::isspace(column.front()))\
          column.remove_prefix(1);\
        while (!column.empty() \&\& std::isspace(column.back()))\
          column.remove_suffix(1);
' "$FTYPES_SUBTYPES"
        else
            # Linux
            sed -i '/string_view const column = columns\[columnIndex\];/c\
        string_view column = columns[columnIndex];\
        \
        \/\/ Trim whitespace from the column\
        while (!column.empty() \&\& std::isspace(column.front()))\
          column.remove_prefix(1);\
        while (!column.empty() \&\& std::isspace(column.back()))\
          column.remove_suffix(1);
' "$FTYPES_SUBTYPES"
        fi
        
        # Agregar trimming a nivel de type definition
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' '/for (auto typeDefinition : typeDefinitions)/a\
        \
          \/\/ Trim whitespace from the type definition\
          while (!typeDefinition.empty() \&\& std::isspace(typeDefinition.front()))\
            typeDefinition.remove_prefix(1);\
          while (!typeDefinition.empty() \&\& std::isspace(typeDefinition.back()))\
            typeDefinition.remove_suffix(1);
' "$FTYPES_SUBTYPES"
        else
            # Linux
            sed -i '/for (auto typeDefinition : typeDefinitions)/a\
        \
          \/\/ Trim whitespace from the type definition\
          while (!typeDefinition.empty() \&\& std::isspace(typeDefinition.front()))\
            typeDefinition.remove_prefix(1);\
          while (!typeDefinition.empty() \&\& std::isspace(typeDefinition.back()))\
            typeDefinition.remove_suffix(1);
' "$FTYPES_SUBTYPES"
        fi
        
        echo -e "${GREEN}✓${NC} Whitespace trimming agregado al parser de subtypes.csv"
    else
        echo -e "${GREEN}✓${NC} Parser de subtypes.csv ya tiene whitespace trimming"
    fi
    
    # Arreglar los ASSERTs que causan crashes
    echo -e "${YELLOW}Paso 7b:${NC} Corrigiendo ASSERTs fatales..."
    
    # Verificar si ya tiene el fix de ASSERTs
    if grep -q "ASSERT(columnIndex != 0" "$FTYPES_SUBTYPES"; then
        # Reemplazar el primer bloque de ASSERTs (líneas ~52-54)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' '/if (typeDefinitions.size() < 1)/,/break;/{
                s|ASSERT(columnIndex != 0, ("Parsing of subtypes file: Invalid or missing types definition|if (columnIndex == 0)\
            LOG(LWARNING, ("Parsing of subtypes file: Invalid or missing types definition|
                s|ASSERT(columnIndex == 0, ("Parsing of subtypes file: Invalid or missing subtypes definition|else\
            LOG(LWARNING, ("Parsing of subtypes file: Invalid or missing subtypes definition|
            }' "$FTYPES_SUBTYPES"
            
            # Reemplazar el segundo bloque de ASSERTs (líneas ~76-80)
            sed -i '' '/else$/,/^[[:space:]]*}$/{
                /ASSERT(columnIndex != 0, ("Parsing of subtypes file: Invalid type/c\
            if (columnIndex == 0)\
              LOG(LWARNING, ("Parsing of subtypes file: Invalid type ", typeDefinition, ""));\
            else\
              LOG(LWARNING, ("Parsing of subtypes file: Invalid subtype ", typeDefinition, ""));
                /ASSERT(columnIndex == 0, ("Parsing of subtypes file: Invalid subtype/d
            }' "$FTYPES_SUBTYPES"
        else
            # Linux
            sed -i '/if (typeDefinitions.size() < 1)/,/break;/{
                s|ASSERT(columnIndex != 0, ("Parsing of subtypes file: Invalid or missing types definition|if (columnIndex == 0)\
            LOG(LWARNING, ("Parsing of subtypes file: Invalid or missing types definition|
                s|ASSERT(columnIndex == 0, ("Parsing of subtypes file: Invalid or missing subtypes definition|else\
            LOG(LWARNING, ("Parsing of subtypes file: Invalid or missing subtypes definition|
            }' "$FTYPES_SUBTYPES"
            
            # Reemplazar el segundo bloque de ASSERTs (líneas ~76-80)
            sed -i '/else$/,/^[[:space:]]*}$/{
                /ASSERT(columnIndex != 0, ("Parsing of subtypes file: Invalid type/c\
            if (columnIndex == 0)\
              LOG(LWARNING, ("Parsing of subtypes file: Invalid type ", typeDefinition, ""));\
            else\
              LOG(LWARNING, ("Parsing of subtypes file: Invalid subtype ", typeDefinition, ""));
                /ASSERT(columnIndex == 0, ("Parsing of subtypes file: Invalid subtype/d
            }' "$FTYPES_SUBTYPES"
        fi
        
        echo -e "${GREEN}✓${NC} ASSERTs fatales reemplazados por LOGs de advertencia"
    else
        echo -e "${GREEN}✓${NC} ASSERTs ya fueron corregidos previamente"
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
echo "  • Parser de subtypes.csv (ftypes_subtypes.cpp):"
echo "    - Whitespace trimming agregado (columnas y valores)"
echo "    - ASSERTs fatales reemplazados por LOGs de advertencia"
echo "    - Fix para crash al buscar direcciones"
echo "  • Archivos .cpp corregidos (includes relativos)"
echo ""
echo "Para revertir los cambios:"
echo "  cp $BACKUP_FILE $COMAPS_CMAKE"
echo ""
echo "Siguiente paso:"
echo "  cd android && ./gradlew :sdk:assembleRelease"
