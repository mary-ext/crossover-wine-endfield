#!/usr/bin/env bash
# Set up a CrossOver Preview app and ARM64 bottle with the FEX port.
#
# Usage:
#   experiments/fex/setup.sh [all]    # app -> bottle -> install
#   experiments/fex/setup.sh <step>   # app | bottle | install
#
# Env: CX_PREVIEW_APP  crossover-preview-arm64-<version>.zip path or URL (required for 'app')
#      APP_SHA256      expected zip checksum (default: pinned for 20260821; empty skips)
#      FROM_BOTTLE     existing Endfield bottle directory to clone the game, profile and
#                      registry settings from (optional for 'bottle'; default: empty bottle)
#      FROM_APP        CrossOver used to export FROM_BOTTLE's registry (default /Applications/CrossOver.app)
#      BOTTLE (default Endfield-FEX), BUILD_DIR (default <repo>/build/fex)
#
# Quit the game and CrossOver before cloning: registry export runs Wine in FROM_BOTTLE.

set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO/experiments/fex/lib.sh"
BUILD_DIR="${BUILD_DIR:-$REPO/build/fex}"
BOTTLE="${BOTTLE:-Endfield-FEX}"
APP="$BUILD_DIR/CrossOver FEX.app"
CXR="$APP/Contents/SharedSupport/CrossOver"
export CX_BOTTLE_PATH="$BUILD_DIR/bottles"
PREFIX="$CX_BOTTLE_PATH/$BOTTLE"
# Original files replaced by 'install', saved once and kept across 'app' reruns.
STOCK="$BUILD_DIR/stock"
APP_SHA256="${APP_SHA256-cbfff89622fcac5028db07e6f48ed4b1abb40dc948fbe8ccb3988fb4a08d2869}"
FROM_APP="${FROM_APP:-/Applications/CrossOver.app}"
# Game data relative to drive_c; cloned copy-on-write where the filesystem supports it.
GAME_DIRS=(
  "Program Files/GRYPHLINK"
  "users/crossover/AppData/Local/Games"
  "users/crossover/AppData/LocalLow/Gryphline"
  "users/crossover/AppData/Roaming/Gryphline"
)
GAME_KEYS=('HKCU\Software\Gryphline' 'HKCU\Software\GRYPHLINK' 'HKCU\Software\Hypergryph')
wine(){ "$CXR/bin/wine" --bottle "$BOTTLE" --debugmsg -all "$@"; }
# Wine resolves Z: to the Unix root in both bottles.
winepath_unix(){ printf 'Z:%s' "${1//\//\\}"; }

cmd_app() {
  local zip
  log "Extracting CrossOver Preview into $APP"
  [ -n "${CX_PREVIEW_APP:-}" ] || die "set CX_PREVIEW_APP to the crossover-preview-arm64-<version>.zip path or URL"
  mkdir -p "$BUILD_DIR"
  zip="$(input_path "$CX_PREVIEW_APP" "$BUILD_DIR/crossover-preview-arm64.zip")"
  check_sha "$zip" "$APP_SHA256"
  rm -rf "$APP" "$BUILD_DIR/app-extract"
  ditto -x -k "$zip" "$BUILD_DIR/app-extract"
  mv "$BUILD_DIR/app-extract/CrossOver Preview.app" "$APP"
  rm -rf "$BUILD_DIR/app-extract"
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  [ -f "$CXR/lib/wine/aarch64-windows/xtajit64.dll" ] || die "not an ARM64 FEX preview: $APP"
  ok "$(defaults read "$APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo unknown)"
}

cmd_bottle() {
  local src="${FROM_BOTTLE:-}" dir key reg="$BUILD_DIR/game-settings.reg"
  [ -x "$CXR/bin/wine" ] || die "run 'app' first"
  [ ! -e "$PREFIX" ] || die "$PREFIX exists; delete it to recreate the bottle"
  log "Creating ARM64 bottle $BOTTLE"
  mkdir -p "$CX_BOTTLE_PATH"
  # Store settings in the bottle so GUI launches use them too.
  "$CXR/bin/cxbottle" --bottle "$BOTTLE" --create --template win11_64 --winearch arm64 \
    --param Bottle:Preview=1 \
    --param EnvironmentVariables:WINEMSYNC=1 \
    --param EnvironmentVariables:FEX_HIDEHYPERVISORBIT=1 \
    --param EnvironmentVariables:MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=0 >/dev/null
  "$CXR/bin/wineserver-arm64" -w
  ok "$PREFIX"
  [ -n "$src" ] || { ok "empty bottle; install the game with the GRYPHLINK launcher"; return; }
  src="${src%/}"

  [ -f "$src/cxbottle.conf" ] || die "FROM_BOTTLE is not a CrossOver bottle: $src"
  log "Cloning game files from $src"
  for dir in "${GAME_DIRS[@]}"; do
    [ -d "$src/drive_c/$dir" ] || continue
    mkdir -p "$(dirname "$PREFIX/drive_c/$dir")"
    cp -Rc "$src/drive_c/$dir" "$PREFIX/drive_c/$dir"
    ok "$dir"
  done
  log "Copying game registry settings"
  for key in "${GAME_KEYS[@]}"; do
    # Export with the bottle's own CrossOver; FEX's Wine must not open an x86_64 prefix.
    CX_BOTTLE_PATH="$(dirname "$src")" "$FROM_APP/Contents/SharedSupport/CrossOver/bin/wine" \
      --bottle "$(basename "$src")" --debugmsg -all reg export "$key" "$(winepath_unix "$reg")" /y >/dev/null 2>&1 || continue
    wine reg import "$(winepath_unix "$reg")" >/dev/null 2>&1 || die "import failed: $key"
    ok "$key"
  done
  rm -f "$reg"
  "$CXR/bin/wineserver-arm64" -w
}

# Patch the hypervisor CPUID leaf handlers of Preview 20260821's FEX build (FEX-2604-755-g80951b9).
XTAJIT_STOCK=fc0f0a37cf15de065ff54e49a11ef37cc05a286a0962f7449dfb632da9da25e7
XTAJIT_PATCHED=d05daeb158e5172d1ecc22c942d111f05525108c81de2da979cf9176a36373f0
patch_xtajit() {
  local f="$1" sum ret0='\x00\x00\x80\xd2\x01\x00\x80\xd2\xc0\x03\x5f\xd6'  # mov x0,#0; mov x1,#0; ret
  sum="$(shasum -a 256 "$f" | cut -d' ' -f1)"
  [ "$sum" = "$XTAJIT_PATCHED" ] && return
  [ "$sum" = "$XTAJIT_STOCK" ] || die "unknown xtajit64.dll build: $f"
  [ -f "$STOCK/xtajit64.dll" ] || cp "$f" "$STOCK/xtajit64.dll"
  # Function_4000_0000h and Function_4000_0001h; file offsets equal RVAs in this image.
  printf '%b' "$ret0" | dd of="$f" bs=1 seek=$((0x1e8d0)) conv=notrunc 2>/dev/null
  printf '%b' "$ret0" | dd of="$f" bs=1 seek=$((0x1e8f8)) conv=notrunc 2>/dev/null
  [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$XTAJIT_PATCHED" ] || die "xtajit64.dll patch failed: $f"
}

# install_file SRC DEST STOCK_NAME: saves the original once, then replaces it.
install_file() {
  [ ! -f "$2" ] || [ -f "$STOCK/$3" ] || cp "$2" "$STOCK/$3"
  cp "$1" "$2"
}

cmd_install() {
  local out="$BUILD_DIR/wine-out" mvk="$BUILD_DIR/moltenvk-out/libMoltenVK.dylib" m name built app_ver
  local base="$PREFIX/drive_c/Program Files/AntiCheatExpert/ACE-BASE.sys"
  [ -x "$CXR/bin/wine" ] && [ -d "$PREFIX/drive_c/windows/system32" ] || die "run 'app' and 'bottle' first"
  [ -f "$out/ntdll.so" ] || die "$out not built — run experiments/fex/build-wine.sh"
  built="$(cat "$BUILD_DIR/wine-out.version")"
  app_ver="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString)"
  [ "$built" = "$app_ver" ] || die "modules were built for Preview $built; the app is $app_ver"
  lipo -verify_arch arm64 "$mvk" 2>/dev/null \
    || die "$mvk is missing or not arm64 — build it with MVK_ARCH=arm64 (see experiments/fex/README.md)"
  log "Installing patched modules"
  "$CXR/bin/wineserver-arm64" -k 2>/dev/null || true
  "$CXR/bin/wineserver-arm64" -w
  mkdir -p "$STOCK"
  for m in "$out"/*.dll "$out"/*.exe "$out"/*.sys; do
    name="$(basename "$m")"
    install_file "$m" "$CXR/lib/wine/aarch64-windows/$name" "app-$name"
    install_file "$m" "$PREFIX/drive_c/windows/system32/$name" "bottle-$name"
    ok "$name"
  done
  install_file "$out/ntdll.so" "$CXR/lib/wine/aarch64-unix/ntdll.so" ntdll.so
  ok "ntdll.so"
  install_file "$mvk" "$CXR/lib/aarch64/libMoltenVK.dylib" libMoltenVK.dylib
  codesign --force --sign - "$CXR/lib/aarch64/libMoltenVK.dylib" 2>/dev/null
  ok "libMoltenVK.dylib"
  # Wine loads the bottle copy; patch the app copy for new bottles too.
  patch_xtajit "$CXR/lib/wine/aarch64-windows/xtajit64.dll"
  patch_xtajit "$PREFIX/drive_c/windows/system32/xtajit64.dll"
  ok "xtajit64.dll (hypervisor CPUID leaves hidden)"
  # x64 drivers need an x64 host; wine-preview/0007 selects winedevice-x64.exe for them.
  cp "$CXR/lib/wine/x86_64-windows/winedevice.exe" "$PREFIX/drive_c/windows/system32/winedevice-x64.exe"
  ok "winedevice-x64.exe"

  if [ -f "$base" ]; then
    log "Registering the game's ACE-BASE driver"
    cp "$base" "$PREFIX/drive_c/windows/system32/drivers/ACE-BASE.sys"
    # On reinstall the service exists, and Wine's 'sc config' can't update a driver service.
    wine sc create ACE-BASE type= kernel start= auto \
      binPath= 'C:\windows\system32\drivers\ACE-BASE.sys' >/dev/null 2>&1 \
      || wine reg add 'HKLM\System\CurrentControlSet\Services\ACE-BASE' /v Start /t REG_DWORD /d 2 /f >/dev/null
    ok "ACE-BASE (automatic start)"
  else
    printf '\n  ACE is missing. Run experiments/fex/run.sh to install it.\n'
    printf '  After the game exits with 13-131078-288, run experiments/fex/setup.sh install.\n'
  fi
  "$CXR/bin/wineserver-arm64" -w
}

case "${1:-all}" in
  app|bottle|install) "cmd_$1" ;;
  all) cmd_app; cmd_bottle; cmd_install ;;
  *) echo "usage: $0 [all|app|bottle|install]"; exit 1 ;;
esac
