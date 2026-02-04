#!/bin/bash

# Script para verificar que el plugin está correctamente configurado

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Verificando configuración de Organic Maps Flutter Plugin"
echo "==========================================================="
echo ""

ERRORS=0
WARNINGS=0

# Verificar Flutter
echo -n "Flutter SDK: "
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    echo -e "${GREEN}✓${NC} $FLUTTER_VERSION"
else
    echo -e "${RED}✗${NC} No encontrado"
    ERRORS=$((ERRORS + 1))
fi

# Verificar CoMaps
echo -n "Librería CoMaps: "
COMAPS_DIR="$(dirname "$PWD")/comaps"
if [ -d "$COMAPS_DIR" ]; then
    echo -e "${GREEN}✓${NC} $COMAPS_DIR"
    
    # Verificar CMakeLists.txt
    if [ -f "$COMAPS_DIR/CMakeLists.txt" ]; then
        echo -e "  ${GREEN}✓${NC} CMakeLists.txt encontrado"
    else
        echo -e "  ${RED}✗${NC} CMakeLists.txt no encontrado"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verificar submódulos críticos
    echo "  Verificando submódulos críticos:"
    SUBMODULES=(
        "3party/expat/expat/CMakeLists.txt"
        "3party/jansson/jansson/CMakeLists.txt"
        "3party/freetype/freetype/CMakeLists.txt"
        "3party/gflags/CMakeLists.txt"
        "3party/glaze/CMakeLists.txt"
    )
    
    MISSING_SUBMODULES=0
    for submodule in "${SUBMODULES[@]}"; do
        if [ -f "$COMAPS_DIR/$submodule" ]; then
            echo -e "    ${GREEN}✓${NC} $(dirname $submodule)"
        else
            echo -e "    ${RED}✗${NC} $(dirname $submodule)"
            MISSING_SUBMODULES=$((MISSING_SUBMODULES + 1))
        fi
    done
    
    if [ $MISSING_SUBMODULES -gt 0 ]; then
        echo -e "  ${RED}✗${NC} $MISSING_SUBMODULES submódulos faltantes"
        echo "    Ejecuta: ./bootstrap.sh"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} No encontrado en $COMAPS_DIR"
    echo "  Ejecuta: ./bootstrap.sh"
    ERRORS=$((ERRORS + 1))
fi

# Verificar Android NDK
echo -n "Android NDK: "
if [ -n "$ANDROID_HOME" ]; then
    NDK_DIR="$ANDROID_HOME/ndk/28.2.13676358"
    if [ -d "$NDK_DIR" ]; then
        echo -e "${GREEN}✓${NC} $NDK_DIR"
    else
        echo -e "${YELLOW}⚠${NC} Versión 28.2.13676358 no encontrada"
        echo "  Instala desde Android Studio > SDK Manager > SDK Tools > NDK"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}⚠${NC} ANDROID_HOME no configurado"
    WARNINGS=$((WARNINGS + 1))
fi

# Verificar CMake
echo -n "CMake: "
if [ -n "$ANDROID_HOME" ]; then
    CMAKE_DIR="$ANDROID_HOME/cmake/3.22.1"
    if [ -d "$CMAKE_DIR" ]; then
        echo -e "${GREEN}✓${NC} $CMAKE_DIR"
    else
        echo -e "${YELLOW}⚠${NC} Versión 3.22.1 no encontrada en Android SDK"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

if command -v cmake &> /dev/null; then
    CMAKE_VERSION=$(cmake --version | head -n 1)
    echo -e "  ${GREEN}✓${NC} Sistema: $CMAKE_VERSION"
else
    echo -e "  ${YELLOW}⚠${NC} CMake no encontrado en sistema"
fi

# Verificar build.gradle
echo -n "Configuración Android: "
if [ -f "android/build.gradle" ]; then
    if grep -q "path '../../CMakeLists.txt'" android/build.gradle; then
        echo -e "${GREEN}✓${NC} build.gradle apunta a CoMaps"
    else
        echo -e "${YELLOW}⚠${NC} build.gradle no apunta a ../../CMakeLists.txt"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}✗${NC} android/build.gradle no encontrado"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "==========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ Plugin configurado correctamente!${NC}"
    echo ""
    echo "Puedes usar el plugin en tu app con:"
    echo "  dependencies:"
    echo "    organic_maps_flutter:"
    echo "      path: ../organic_maps_flutter"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Configuración completa con $WARNINGS advertencias${NC}"
    exit 0
else
    echo -e "${RED}✗ Encontrados $ERRORS errores y $WARNINGS advertencias${NC}"
    echo ""
    echo "Ejecuta el bootstrap para resolver:"
    echo "  ./bootstrap.sh"
    exit 1
fi
