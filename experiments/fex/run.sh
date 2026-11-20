#!/usr/bin/env bash
# Launch Endfield in the FEX bottle prepared by setup.sh, through tools/direct-launch.c (the game
# refuses to start without the GRYPHLINK launcher as its parent). Extra arguments go to the game.
# Env: FEX_WINEDEBUG (Wine debug channels, default -all), BOTTLE, BUILD_DIR.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO/experiments/fex/lib.sh"
SRC="$REPO/tools/direct-launch.c"
EXE="$BUILD_DIR/direct-launch.exe"
CC="$TOOLCHAIN/x86_64-w64-mingw32-clang"

if [ ! -f "$EXE" ] || [ "$SRC" -nt "$EXE" ]; then
  [ -x "$CC" ] || die "no llvm-mingw toolchain — run experiments/fex/build-wine.sh toolchain"
  "$CC" -O2 -municode -o "$EXE" "$SRC" || die "building direct-launch.exe failed"
fi
exec "$CXR/bin/wine" --bottle "$BOTTLE" --debugmsg "${FEX_WINEDEBUG:--all}" "$EXE" -- "$@"
