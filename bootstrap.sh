#!/bin/bash
set -e

echo "🗺️  Bootstrap Organic Maps Flutter Plugin"
echo "=========================================="

# Este script normalmente no se ejecuta directamente
# Se ejecuta desde el bootstrap de la app

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMAPS_DIR="$(dirname "$PLUGIN_ROOT")/comaps"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}Verificando CoMaps...${NC}"

if [ ! -d "$COMAPS_DIR" ]; then
    echo -e "${RED}✗${NC} CoMaps no encontrado en $COMAPS_DIR"
    echo "Este script debe ejecutarse desde el bootstrap de la app principal"
    exit 1
fi

echo -e "${GREEN}✓${NC} CoMaps encontrado"

echo ""
echo -e "${YELLOW}Verificando submódulos de CoMaps...${NC}"

cd "$COMAPS_DIR"

if [ ! -f "3party/expat/expat/CMakeLists.txt" ]; then
    echo "Inicializando submódulos..."
    git submodule update --init --recursive --depth 1
else
    echo -e "${GREEN}✓${NC} Submódulos ya inicializados"
fi

echo ""
echo -e "${YELLOW}Configurando CoMaps...${NC}"

if [ -f "configure.sh" ]; then
    chmod +x configure.sh
    ./configure.sh
else
    echo -e "${RED}✗${NC} configure.sh no encontrado"
    exit 1
fi

echo ""
echo -e "${YELLOW}Instalando dependencias del plugin...${NC}"
cd "$PLUGIN_ROOT"
flutter pub get

echo ""
echo -e "${GREEN}✅ Plugin configurado correctamente!${NC}"

echo ""
echo -e "${YELLOW}Paso 2/4:${NC} Inicializando submódulos de CoMaps..."
cd "$COMAPS_DIR"

# Verificar si los submódulos están inicializados
if [ ! -f "3party/expat/expat/CMakeLists.txt" ]; then
    echo "Inicializando submódulos (esto puede tardar)..."
    git submodule update --init --recursive --depth 1
else
    echo -e "${GREEN}✓${NC} Submódulos ya inicializados"
fi

echo ""
echo -e "${YELLOW}Paso 3/4:${NC} Configurando CoMaps..."
cd "$COMAPS_DIR"

if [ -f "configure.sh" ]; then
    chmod +x configure.sh
    ./configure.sh
else
    echo -e "${RED}✗${NC} No se encontró configure.sh en CoMaps"
    exit 1
fi

echo ""
echo -e "${YELLOW}Paso 4/4:${NC} Instalando dependencias del plugin..."
cd "$PLUGIN_ROOT"
flutter pub get

echo ""
echo -e "${GREEN}✅ Bootstrap del plugin completado!${NC}"
echo ""
echo "Estructura de directorios:"
echo "  $(dirname "$PLUGIN_ROOT")/"
echo "  ├── comaps/                    (librería C++)"
echo "  └── organic_maps_flutter/      (plugin Flutter)"
