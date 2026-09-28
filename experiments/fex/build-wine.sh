#!/usr/bin/env bash
# Build patched ARM64 Wine modules from CrossOver Preview's Wine source into build/fex/wine-out.
#
# Usage:
#   experiments/fex/build-wine.sh [all]    # deps -> toolchain -> fetch -> apply -> configure -> build
#   experiments/fex/build-wine.sh <step>   # deps | toolchain | fetch | apply | configure | build
#
# Env: CX_PREVIEW_SRC  crossover-sources-<version>.tar.gz path or URL (required for 'fetch')
#      CX_PREVIEW_VER  preview version (default 20260821, the patch target)
#      SRC_SHA256      expected tarball checksum (default: pinned for 20260821; empty skips)
#      BUILD_DIR (default <repo>/build/fex), JOBS (default: all cores)

set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO/experiments/fex/lib.sh"
CX_PREVIEW_VER="${CX_PREVIEW_VER:-20260821}"
if [ "$CX_PREVIEW_VER" = 20260821 ]; then
  SRC_SHA256="${SRC_SHA256-c6129605ae6e9c323c279238b9ca748dcb19a409cd04760319e51ee433cd6780}"
else
  SRC_SHA256="${SRC_SHA256-}"
fi
BUILD_DIR="${BUILD_DIR:-$REPO/build/fex}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
WINE_SRC="$BUILD_DIR/wine-src"
WINE_BUILD="$BUILD_DIR/wine-build"
WINE_OUT="$BUILD_DIR/wine-out"
LLVM_MINGW=llvm-mingw-20260922-ucrt-macos-universal
LLVM_MINGW_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/20260922/$LLVM_MINGW.tar.xz"
LLVM_MINGW_SHA256=52e5f5a7b131021d0c39a37a38fa380a1da7885cd04bd61afd0cd4ecfb8bc1f3
TOOLCHAIN="$BUILD_DIR/$LLVM_MINGW/bin"
MODULES="dlls/ntdll/ntdll.so dlls/ntdll/aarch64-windows/ntdll.dll dlls/kernel32/aarch64-windows/kernel32.dll
  dlls/ntoskrnl.exe/aarch64-windows/ntoskrnl.exe dlls/wdfldr.sys/aarch64-windows/wdfldr.sys
  programs/services/aarch64-windows/services.exe"
BREW="$(command -v brew || echo /opt/homebrew/bin/brew)"
export MACOSX_DEPLOYMENT_TARGET=14.0

# Shared patch selection: patches/README.md#wine-preview.
P="$REPO/patches/wine"
SHARED_PATCHES=(
  "$P"/dwproton/em-backports/00{03,04,05,06,07,08,09,10,11,12,13,14,15,17}-*.patch
  "$P"/dwproton/misc/00{09,10}-*.patch
  "$P"/macos/0005-*.patch
)

use_tools(){ export PATH="$TOOLCHAIN:$("$BREW" --prefix bison)/bin:$PATH"; }  # Wine needs bison >= 3.0

cmd_deps() {
  log "Installing Homebrew build dependencies"
  "$BREW" install autoconf bison || exit 1
}

cmd_toolchain() {
  local txz
  log "Fetching $LLVM_MINGW"
  [ -x "$TOOLCHAIN/arm64ec-w64-mingw32-clang" ] && { echo "already present"; return; }
  mkdir -p "$BUILD_DIR"
  txz="$(input_path "$LLVM_MINGW_URL" "$BUILD_DIR/$LLVM_MINGW.tar.xz")" || exit 1
  check_sha "$txz" "$LLVM_MINGW_SHA256"
  tar xJf "$txz" -C "$BUILD_DIR" || die "extract failed"
  rm -f "$txz"
  # Downloaded binaries are quarantined; Gatekeeper would prompt for each one.
  xattr -dr com.apple.quarantine "$BUILD_DIR/$LLVM_MINGW" 2>/dev/null || true
}

cmd_fetch() {
  local tgz
  log "Extracting CrossOver Preview ${CX_PREVIEW_VER} sources/wine"
  [ -n "${CX_PREVIEW_SRC:-}" ] || die "set CX_PREVIEW_SRC to the crossover-sources-${CX_PREVIEW_VER}.tar.gz path or URL"
  mkdir -p "$BUILD_DIR"
  tgz="$(input_path "$CX_PREVIEW_SRC" "$BUILD_DIR/crossover-sources-${CX_PREVIEW_VER}.tar.gz")" || exit 1
  check_sha "$tgz" "$SRC_SHA256"
  rm -rf "$WINE_SRC" "$BUILD_DIR/sources"
  tar xzf "$tgz" -C "$BUILD_DIR" sources/wine || die "extract failed"
  mv "$BUILD_DIR/sources/wine" "$WINE_SRC" && rm -rf "$BUILD_DIR/sources" || exit 1
  # Keep a baseline for reapplying and inspecting patches.
  ( cd "$WINE_SRC" && git init -q && git add -A && git -c user.email=build@localhost -c user.name=build commit -qm "vanilla CrossOver Preview ${CX_PREVIEW_VER} wine" ) || exit 1
  echo "Wine source: $WINE_SRC ($(cat "$WINE_SRC/VERSION"))"
}

cmd_apply() {
  local f n=0
  log "Applying shared patches, then patches/wine-preview"
  [ -d "$WINE_SRC/.git" ] || die "run 'fetch' first"
  # Reset the source tree; unchanged files keep their mtimes.
  git -C "$WINE_SRC" reset -q --hard && git -C "$WINE_SRC" clean -fdq || exit 1
  for f in "${SHARED_PATCHES[@]}" "$REPO"/patches/wine-preview/*.patch; do
    [ -f "$f" ] || die "missing patch: $f"
    git -C "$WINE_SRC" apply --whitespace=nowarn "$f" || die "patch failed: $f"
    n=$((n+1))
  done
  echo "applied $n patches"
}

cmd_configure() {
  log "Configuring ARM64 Wine"
  [ -d "$WINE_SRC" ] || die "run 'fetch' first"
  [ -x "$TOOLCHAIN/arm64ec-w64-mingw32-clang" ] || die "run 'toolchain' first"
  use_tools
  # wine-preview adds dlls/wdfldr.sys to configure.ac.
  ( cd "$WINE_SRC" && autoconf ) || die "autoconf failed"
  rm -rf "$WINE_BUILD"; mkdir -p "$WINE_BUILD"
  # CrossOver's ntdll.so finds its bundled libraries through the lib/aarch64 rpath.
  ( cd "$WINE_BUILD" && CC=/usr/bin/clang CXX=/usr/bin/clang++ \
      LDFLAGS="-Wl,-rpath,@loader_path/../../../lib/aarch64" "$WINE_SRC/configure" \
      --enable-archs=aarch64,arm64ec,x86_64 --with-mingw=llvm-mingw --disable-tests \
      --without-x --without-freetype --without-gnutls --without-sdl --without-vulkan \
      --without-krb5 --without-gstreamer --without-gphoto --without-sane --without-pcap \
      --without-usb --without-cups --without-coreaudio
  ) > "$BUILD_DIR/configure.log" 2>&1 || die "configure failed — see $BUILD_DIR/configure.log"
}

cmd_build() {
  local m
  log "Building ARM64 modules (make -j$JOBS)"
  [ -f "$WINE_BUILD/Makefile" ] || die "run 'configure' first"
  use_tools
  # shellcheck disable=SC2086 # MODULES is a word list
  ( cd "$WINE_BUILD" && make -j"$JOBS" $MODULES ) > "$BUILD_DIR/build.log" 2>&1 \
    || die "make failed — see $BUILD_DIR/build.log"
  rm -rf "$WINE_OUT"; mkdir -p "$WINE_OUT"
  for m in $MODULES; do cp "$WINE_BUILD/$m" "$WINE_OUT/" || exit 1; done
  codesign --force --sign - "$WINE_OUT/ntdll.so" || exit 1
  # Keep the license beside the installable modules.
  cp "$WINE_SRC/COPYING.LIB" "$BUILD_DIR/" || exit 1
  echo "$CX_PREVIEW_VER" > "$BUILD_DIR/wine-out.version"
  echo "built $WINE_OUT"
}

case "${1:-all}" in
  deps|toolchain|fetch|apply|configure|build) "cmd_$1" ;;
  all) cmd_deps; cmd_toolchain; cmd_fetch; cmd_apply; cmd_configure; cmd_build ;;
  *) echo "usage: $0 [all|deps|toolchain|fetch|apply|configure|build]"; exit 1 ;;
esac
