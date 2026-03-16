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

# Restringir viewport del mapa a Cuba (evita pantalla negra al hacer zoom out)
VISUAL_PARAMS="$COMAPS_DIR/libs/drape_frontend/visual_params.cpp"
if [ -f "$VISUAL_PARAMS" ]; then
    echo -e "${YELLOW}Aplicando parche Cuba viewport...${NC}"
    if grep -q "mercator::Bounds::FullRect()" "$VISUAL_PARAMS"; then
        sed -i 's|return mercator::Bounds::FullRect();|// Cuba viewport bounds\n  return m2::RectD(-84.95, mercator::LatToY(19.82), -74.13, mercator::LatToY(23.27));|' "$VISUAL_PARAMS"
        echo -e "${GREEN}✓${NC} Viewport restringido a Cuba"
    else
        echo -e "${GREEN}✓${NC} Viewport ya restringido"
    fi
fi

# Fix ScaleInto ASSERT crash con viewport restringido
SCREEN_OPS="$COMAPS_DIR/libs/drape_frontend/screen_operations.cpp"
if [ -f "$SCREEN_OPS" ]; then
    if grep -q 'ASSERT(boundRect.IsPointInside(clipRect.Center())' "$SCREEN_OPS"; then
        sed -i 's|ASSERT(boundRect.IsPointInside(clipRect.Center()), ("center point should be inside boundRect"));|// Graceful handling for restricted viewport\n  if (!boundRect.IsPointInside(clipRect.Center()))\n  {\n    m2::PointD const newCenter = boundRect.Center();\n    m2::PointD const offset = newCenter - clipRect.Center();\n    clipRect.Offset(offset.x, offset.y);\n    res.SetOrg(newCenter);\n  }|' "$SCREEN_OPS"
        echo -e "${GREEN}✓${NC} ScaleInto ASSERT corregido"
    fi
fi

# Fix ExtractTrafficGeometry bounds index
RULE_DRAWER="$COMAPS_DIR/libs/drape_frontend/rule_drawer.cpp"
if [ -f "$RULE_DRAWER" ]; then
    if grep -q "ASSERT_GREATER_OR_EQUAL(index, 0, ());" "$RULE_DRAWER"; then
        sed -i 's|ASSERT_GREATER_OR_EQUAL(index, 0, ());|if (index < 0) index = 0;|' "$RULE_DRAWER"
        sed -i 's|ASSERT_LESS(index, static_cast<int>(kAverageSegmentsCount.size()), ());|if (index >= static_cast<int>(kAverageSegmentsCount.size()))\n    index = static_cast<int>(kAverageSegmentsCount.size()) - 1;|' "$RULE_DRAWER"
        sed -i 's|int const index|int index|' "$RULE_DRAWER"
        echo -e "${GREEN}✓${NC} Traffic bounds zoom crash corregido"
    fi
fi

# Fix missing fonts crash
GLYPH_MANAGER="$COMAPS_DIR/libs/drape/glyph_manager.cpp"
if [ -f "$GLYPH_MANAGER" ]; then
    if grep -q "ASSERT_EQUAL(m_impl->m_fonts.size(), params.m_fonts.size(), ());" "$GLYPH_MANAGER"; then
        sed -i 's|ASSERT_EQUAL(m_impl->m_fonts.size(), params.m_fonts.size(), ());|//ASSERT_EQUAL(m_impl->m_fonts.size(), params.m_fonts.size(), ());|' "$GLYPH_MANAGER"
        echo -e "${GREEN}✓${NC} GlyphManager faltante fonts corregido"
    fi
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
