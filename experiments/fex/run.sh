#!/usr/bin/env bash
# Launch Endfield in the FEX bottle prepared by setup.sh. Extra arguments go to the game.
# Env: FEX_WINEDEBUG (Wine debug channels, default -all), BOTTLE, BUILD_DIR.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$REPO/build/fex}"
BOTTLE="${BOTTLE:-Endfield-FEX}"
export CX_BOTTLE_PATH="$BUILD_DIR/bottles"
exec "$BUILD_DIR/CrossOver FEX.app/Contents/SharedSupport/CrossOver/bin/wine" --bottle "$BOTTLE" \
    --debugmsg "${FEX_WINEDEBUG:--all}" \
    'C:\Program Files\GRYPHLINK\games\Arknights Endfield\Endfield.exe' "$@"
