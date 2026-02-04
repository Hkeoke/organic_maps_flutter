#!/bin/bash

# Script para verificar que todas las rutas en build.gradle sean correctas

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Verificando rutas de CMakeLists.txt"
echo "========================================"
echo ""

# Verificar build.gradle principal
echo "1. build.gradle principal (android/build.gradle):"
BUILD_GRADLE="android/build.gradle"
if [ -f "$BUILD_GRADLE" ]; then
    CMAKE_PATH=$(grep "path.*CMakeLists.txt" "$BUILD_GRADLE" | grep -v "//" | sed "s/.*path[[:space:]]*['\"]\\(.*\\)['\"].*/\\1/" | xargs)
    echo "   Ruta configurada: $CMAKE_PATH"
    
    # Calcular ruta absoluta desde android/
    FULL_PATH="android/$CMAKE_PATH"
    if [ -f "$FULL_PATH" ]; then
        echo -e "   ${GREEN}✓${NC} Archivo existe: $FULL_PATH"
    else
        echo -e "   ${RED}✗${NC} Archivo NO existe: $FULL_PATH"
    fi
else
    echo -e "   ${RED}✗${NC} No se encontró $BUILD_GRADLE"
fi

echo ""

# Verificar build.gradle del SDK
echo "2. build.gradle del SDK (android/sdk/build.gradle):"
SDK_BUILD_GRADLE="android/sdk/build.gradle"
if [ -f "$SDK_BUILD_GRADLE" ]; then
    CMAKE_PATH=$(grep "path.*CMakeLists.txt" "$SDK_BUILD_GRADLE" | grep -v "//" | sed "s/.*path[[:space:]]*['\"]\\(.*\\)['\"].*/\\1/" | xargs)
    echo "   Ruta configurada: $CMAKE_PATH"
    
    # Calcular ruta absoluta desde android/sdk/
    FULL_PATH="android/sdk/$CMAKE_PATH"
    if [ -f "$FULL_PATH" ]; then
        echo -e "   ${GREEN}✓${NC} Archivo existe: $FULL_PATH"
    else
        echo -e "   ${RED}✗${NC} Archivo NO existe: $FULL_PATH"
    fi
else
    echo -e "   ${RED}✗${NC} No se encontró $SDK_BUILD_GRADLE"
fi

echo ""
echo "========================================"
echo ""

# Mostrar estructura esperada
echo "Estructura esperada:"
echo "  plugins/"
echo "  ├── comaps/"
echo "  │   └── CMakeLists.txt          ← Debe existir"
echo "  └── organic_maps_flutter/"
echo "      └── android/"
echo "          ├── build.gradle        ← path '../comaps/CMakeLists.txt'"
echo "          └── sdk/"
echo "              └── build.gradle    ← path '../../../comaps/CMakeLists.txt'"
