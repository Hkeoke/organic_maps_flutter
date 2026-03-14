#!/bin/bash
# ============================================================================
# optimize_size.sh - Reduce el tamaño del plugin organic_maps_flutter
# ============================================================================
# Este script elimina recursos no necesarios para la app Rikera Taxi:
# - Idiomas: solo mantiene es, en, default
# - Fuentes: elimina scripts no latinos innecesarios
# - Símbolos: elimina densidades bajas (mdpi, default) e innecesariamente altas (xxxhdpi)
# - Estilos: elimina outdoors y vehicle (solo usa default)
# - Shaders Vulkan: elimina si solo usa OpenGL
# - JNI: elimina archivos Java/Kotlin no usados
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/android/sdk/src/main/assets"
JAVA_DIR="$SCRIPT_DIR/android/sdk/src/main/java"
CPP_DIR="$SCRIPT_DIR/android/sdk/src/main/cpp"

echo "============================================"
echo "🔧 Optimizando tamaño del plugin"
echo "============================================"

# Función para calcular tamaño
calc_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

INITIAL_SIZE=$(calc_size "$SCRIPT_DIR/android/sdk/src/main")
echo "📦 Tamaño inicial: $INITIAL_SIZE"
echo ""

# ============================================================================
# 1. IDIOMAS - Solo mantener es, en, default
# ============================================================================
echo "🌐 [1/7] Limpiando idiomas innecesarios..."

# Lista de idiomas a MANTENER
KEEP_LANGS="es en default"

for lang_dir in countries-strings categories-strings sound-strings; do
    if [ -d "$ASSETS_DIR/$lang_dir" ]; then
        for item in "$ASSETS_DIR/$lang_dir"/*; do
            basename=$(basename "$item")
            # Extraer código de idioma (sin .json)
            lang_code="${basename%.json}"
            
            keep=false
            for keep_lang in $KEEP_LANGS; do
                if [ "$lang_code" = "$keep_lang" ]; then
                    keep=true
                    break
                fi
            done
            
            if [ "$keep" = false ]; then
                rm -rf "$item"
            fi
        done
        echo "   ✅ $lang_dir: solo es, en, default"
    fi
done

# ============================================================================
# 2. FUENTES - Eliminar scripts no necesarios para Latinoamérica
# ============================================================================
echo "🔤 [2/7] Limpiando fuentes innecesarias..."

# Solo mantener: latin (dejavu), fallback (droidsans), roboto_medium
# Eliminar: Arabic, Bengali, Hebrew, Malayalam, Thai, Devanagari, Jomolhari (Tibetan), Padauk (Myanmar), Khmer, Code2000
FONTS_TO_REMOVE=(
    "00_NotoNaskhArabic-Regular.ttf"
    "00_NotoSansBengali-Regular.ttf"
    "00_NotoSansHebrew-Regular.ttf"
    "00_NotoSansMalayalam-Regular.ttf"
    "00_NotoSansThai-Regular.ttf"
    "00_NotoSerifDevanagari-Regular.ttf"
    "03_jomolhari-id-a3d.ttf"    # Tibetan
    "04_padauk.ttf"              # Myanmar
    "05_khmeros.ttf"             # Khmer
    "06_code2000.ttf"            # Unicode supplemental (raramente necesario)
)

for font in "${FONTS_TO_REMOVE[@]}"; do
    if [ -f "$ASSETS_DIR/fonts/$font" ]; then
        rm "$ASSETS_DIR/fonts/$font"
        echo "   🗑️  Eliminado: $font"
    fi
done

# ============================================================================
# 3. SÍMBOLOS - Solo mantener densidades comunes
# ============================================================================
echo "📐 [3/7] Limpiando densidades de símbolos innecesarias..."

# Mantener: hdpi, xhdpi, xxhdpi (cubren 90%+ de dispositivos Android)
# Eliminar: mdpi (muy antiguo), default, 6plus (iOS), xxxhdpi (muy pocos dispositivos)
SYMBOLS_TO_REMOVE=("mdpi" "default" "6plus" "xxxhdpi")

for density in "${SYMBOLS_TO_REMOVE[@]}"; do
    if [ -d "$ASSETS_DIR/symbols/$density" ]; then
        rm -rf "$ASSETS_DIR/symbols/$density"
        echo "   🗑️  Eliminada densidad: $density"
    fi
done

# ============================================================================
# 4. ESTILOS - Solo mantener default
# ============================================================================
echo "🎨 [4/7] Limpiando estilos innecesarios..."

# Eliminar estilos outdoors y vehicle (la app usa default)
for style in outdoors vehicle; do
    if [ -d "$ASSETS_DIR/styles/$style" ]; then
        rm -rf "$ASSETS_DIR/styles/$style"
        echo "   🗑️  Eliminado estilo: $style"
    fi
done

# Eliminar drules de estilos no usados
for drules in drules_proto_outdoors_light.bin drules_proto_outdoors_dark.bin drules_proto_vehicle_light.bin drules_proto_vehicle_dark.bin; do
    if [ -f "$ASSETS_DIR/$drules" ]; then
        rm "$ASSETS_DIR/$drules"
        echo "   🗑️  Eliminado: $drules"
    fi
done

# ============================================================================
# 5. VULKAN SHADERS - Eliminar si solo se usa OpenGL  
# ============================================================================
echo "🖥️  [5/7] Limpiando shaders Vulkan..."

if [ -d "$ASSETS_DIR/vulkan_shaders" ]; then
    rm -rf "$ASSETS_DIR/vulkan_shaders"
    echo "   🗑️  Eliminados shaders Vulkan (usando OpenGL ES)"
fi

# ============================================================================
# 6. SEARCH ICONS - No necesarios para la app
# ============================================================================
echo "🔍 [6/7] Limpiando search icons..."

if [ -d "$ASSETS_DIR/search-icons" ]; then
    rm -rf "$ASSETS_DIR/search-icons"
    echo "   🗑️  Eliminados search icons"
fi

# ============================================================================
# 7. RESULTADO
# ============================================================================
echo ""
FINAL_SIZE=$(calc_size "$SCRIPT_DIR/android/sdk/src/main")
echo "============================================"
echo "📦 Tamaño inicial: $INITIAL_SIZE"
echo "📦 Tamaño final:   $FINAL_SIZE"
echo "============================================"
echo ""
echo "⚠️  IMPORTANTE: Después de ejecutar este script:"
echo "   1. Ejecuta 'flutter clean' en el proyecto principal"
echo "   2. Reconstruye la app"
echo "   3. El script NO elimina archivos CPP/JNI del CMakeLists"
echo "      (eso se hace por separado, editando el CMakeLists.txt)"
echo ""
