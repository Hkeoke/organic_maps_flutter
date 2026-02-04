#!/bin/bash
set -e

# Script para sincronizar assets desde CoMaps al plugin Flutter

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMAPS_DATA="$SCRIPT_DIR/../comaps/data"
PLUGIN_ASSETS="$SCRIPT_DIR/android/sdk/src/main/assets"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📦 Sincronizando assets de CoMaps al plugin Flutter${NC}"
echo "=========================================="
echo ""

# Verificar que existe el directorio de datos de CoMaps
if [ ! -d "$COMAPS_DATA" ]; then
    echo -e "${RED}✗${NC} No se encontró el directorio de datos de CoMaps: $COMAPS_DATA"
    exit 1
fi

# Crear directorio de assets si no existe
mkdir -p "$PLUGIN_ASSETS"

echo -e "${YELLOW}Copiando archivos necesarios...${NC}"

# Archivos de texto necesarios
FILES=(
    "countries_meta.txt"
    "countries_synonyms.csv"
    "hierarchy.txt"
    "mixed_nodes.txt"
    "mixed_tags.txt"
    "replaced_tags.txt"
    "subtypes.csv"
    "synonyms.txt"
)

for file in "${FILES[@]}"; do
    if [ -f "$COMAPS_DATA/$file" ]; then
        cp "$COMAPS_DATA/$file" "$PLUGIN_ASSETS/"
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${YELLOW}⚠${NC} $file no encontrado (puede ser opcional)"
    fi
done

# Copiar directorios necesarios si no existen
DIRS=(
    "styles"
    "categories-strings"
    "search-icons"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$COMAPS_DATA/$dir" ]; then
        if [ ! -d "$PLUGIN_ASSETS/$dir" ]; then
            cp -r "$COMAPS_DATA/$dir" "$PLUGIN_ASSETS/"
            echo -e "${GREEN}✓${NC} $dir/ (directorio completo)"
        else
            echo -e "${GREEN}✓${NC} $dir/ (ya existe)"
        fi
    fi
done

echo ""
echo -e "${GREEN}✅ Sincronización completada!${NC}"
echo ""
echo "Assets sincronizados en: $PLUGIN_ASSETS"
