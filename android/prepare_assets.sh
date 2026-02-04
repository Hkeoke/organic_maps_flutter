#!/usr/bin/env bash
#
# Script to prepare assets for the Organic Maps Flutter plugin
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASSETS_DIR="$SCRIPT_DIR/sdk/src/main/assets"

echo "Preparing assets for Organic Maps Flutter plugin..."
echo "Project root: $PROJECT_ROOT"
echo "Assets directory: $ASSETS_DIR"

# Check if symbols are generated
if [ ! -f "$PROJECT_ROOT/data/symbols/xxhdpi/light/symbols.sdf" ]; then
    echo "ERROR: Symbol files not found!"
    echo "Please run the following commands from the project root:"
    echo "  1. Install optipng: sudo apt-get install optipng (or brew install optipng on macOS)"
    echo "  2. Run: bash ./tools/unix/generate_symbols.sh"
    echo ""
    echo "This will generate the required .sdf and .png files for map symbols."
    exit 1
fi

echo "Symbol files found. Assets are ready!"
echo "You can now build the Flutter app."
