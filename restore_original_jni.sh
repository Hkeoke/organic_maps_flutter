#!/bin/bash
set -e

# Script para restaurar el JNI original de CoMaps
# Revierte los cambios hechos por setup_plugin_jni.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMAPS_DIR="$SCRIPT_DIR/../comaps"
COMAPS_CMAKE="$COMAPS_DIR/CMakeLists.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Restaurando JNI original de CoMaps${NC}"
echo "=========================================="
echo ""

# Verificar que existe CoMaps
if [ ! -f "$COMAPS_CMAKE" ]; then
    echo -e "${RED}✗${NC} No se encontró $COMAPS_CMAKE"
    exit 1
fi

# Buscar el backup más reciente
LATEST_BACKUP=$(ls -t "$COMAPS_CMAKE.backup."* 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo -e "${YELLOW}⚠${NC} No se encontró ningún backup"
    echo "Restaurando manualmente..."
    
    # Restaurar la línea original
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|add_subdirectory(../../organic_maps_flutter/android/src/main/cpp)|add_subdirectory(android/sdk/src/main/cpp)|g" "$COMAPS_CMAKE"
    else
        # Linux
        sed -i "s|add_subdirectory(../../organic_maps_flutter/android/src/main/cpp)|add_subdirectory(android/sdk/src/main/cpp)|g" "$COMAPS_CMAKE"
    fi
    
    echo -e "${GREEN}✓${NC} Línea restaurada manualmente"
else
    echo -e "${YELLOW}Usando backup:${NC} $LATEST_BACKUP"
    cp "$LATEST_BACKUP" "$COMAPS_CMAKE"
    echo -e "${GREEN}✓${NC} CMakeLists.txt restaurado desde backup"
fi

# Verificar el cambio
echo ""
echo "Línea actual:"
grep -A 1 "if (PLATFORM_ANDROID)" "$COMAPS_CMAKE" | tail -n 1
echo ""

echo -e "${GREEN}✅ JNI original restaurado!${NC}"
