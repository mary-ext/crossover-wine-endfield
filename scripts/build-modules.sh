#!/usr/bin/env bash
# build-modules.sh — build the patched Wine modules (ntdll.so, kernel32.dll, ntoskrnl.exe) from
# CrossOver's Wine source and package them for apply-modules.sh / install-release.sh.
#
# Endfield is 64-bit only, so this configures a minimal 64-bit-only Wine with the standard
# toolchain (no win32on64 / cx-llvm) and builds just the three modules we swap into CrossOver.
#
# Usage:
#   scripts/build-modules.sh [all]    # deps -> fetch -> apply -> configure -> build -> package
#   scripts/build-modules.sh <step>   # deps | fetch | apply | configure | build | package
#
# Env: CX_VER (default 26.3.0), BUILD_DIR (default <repo>/build), DIST_DIR (default <repo>/dist),
#      JOBS (default: all cores), FULL=1 (build the whole Wine tree instead of the three modules)

set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CX_VER="${CX_VER:-26.3.0}"
BUILD_DIR="${BUILD_DIR:-$REPO/build}"
DIST_DIR="${DIST_DIR:-$REPO/dist}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
SRC_URL="https://media.codeweavers.com/pub/crossover/source/crossover-sources-${CX_VER}.tar.gz"
WINE_SRC="$BUILD_DIR/wine-src"          # extracted sources/wine
WINE_BUILD="$BUILD_DIR/wine-build64"    # out-of-tree 64-bit build
PKG_NAME="endfield-wine-modules"
BREW="$(command -v brew || echo /opt/homebrew/bin/brew)"
# Command Line Tools 27+ ship arm64-only binaries: the /usr/bin/clang xcrun shim can't load
# libxcrun.dylib under `arch -x86_64`. So call the real (native) clang directly, targeting x86_64,
# with an explicit SDK. The resulting binaries are x86_64, run under Rosetta, so configure is not
# cross-compiling.
CLT_BIN="$(xcode-select -p)/usr/bin"; [ -x "$CLT_BIN/clang" ] || CLT_BIN="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin"
SDK="${SDKROOT:-$(xcrun --show-sdk-path)}"
TOOLCHAIN_ENV='export PATH="'"$CLT_BIN"':$PATH" SDKROOT="'"$SDK"'" MACOSX_DEPLOYMENT_TARGET=10.15'

log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }

cmd_deps() {
  log "Installing Homebrew build dependencies"
  # Only what the minimal configure below needs (all optional libs are --without-*).
  "$BREW" install bison mingw-w64 pkgconf || exit 1
}

cmd_fetch() {
  log "Fetching CrossOver ${CX_VER} source (~150 MB) and extracting sources/wine"
  mkdir -p "$BUILD_DIR"
  local tgz="$BUILD_DIR/crossover-sources-${CX_VER}.tar.gz"
  [ -f "$tgz" ] || curl -fL "$SRC_URL" -o "$tgz" || { echo "download failed ($SRC_URL)"; exit 1; }
  rm -rf "$WINE_SRC" "$BUILD_DIR/sources"; mkdir -p "$WINE_SRC"
  tar xzf "$tgz" -C "$BUILD_DIR" sources/wine || { echo "extract failed"; exit 1; }
  mv "$BUILD_DIR/sources/wine"/* "$WINE_SRC/"; rm -rf "$BUILD_DIR/sources"
  # git-init the tree so patches apply with `git apply` and can be diffed
  ( cd "$WINE_SRC" && git init -q && git add -A && git -c user.email=build@localhost -c user.name=build commit -qm "vanilla CrossOver ${CX_VER} wine" ) || exit 1
  echo "wine source ready at: $WINE_SRC ($(cat "$WINE_SRC/VERSION"))"
}

cmd_apply() {
  log "Applying patches (em-backports -> misc -> macos Rosetta fixes)"
  [ -d "$WINE_SRC/.git" ] || { echo "run 'fetch' first"; exit 1; }
  local P="$REPO/patches"
  ( cd "$WINE_SRC"
    n=0
    for f in $(ls "$P"/stage2-dwproton/em-backports/*.patch | sort) \
             $(ls "$P"/stage2-dwproton/misc/*.patch | sort) \
             "$P"/stage1-macos/0000-*.patch "$P"/stage1-macos/0001-*.patch; do
      git apply "$f" || { echo "FAILED to apply: $f"; exit 1; }
      n=$((n+1))
    done
    echo "applied $n patches cleanly" ) || exit 1
}

cmd_configure() {
  log "Configuring 64-bit-only Wine"
  [ -d "$WINE_SRC" ] || { echo "run 'fetch' first"; exit 1; }
  rm -rf "$WINE_BUILD"; mkdir -p "$WINE_BUILD"
  # CrossOver on Apple Silicon builds as x86_64 under Rosetta. Run configure+make under
  # `arch -x86_64` so __x86_64__ is defined for the unix objects. Homebrew libs are arm64-only,
  # so the optional externals are disabled; CrossOver already provides them at runtime.
  arch -x86_64 /bin/bash -c '
    '"$TOOLCHAIN_ENV"'
    export PATH="'"$("$BREW" --prefix bison)"'/bin:$PATH"
    echo "host arch: $(uname -m); bison: $(bison --version | head -1); sdk: $SDKROOT"
    cd "'"$WINE_BUILD"'"
    CC="clang -arch x86_64" CXX="clang++ -arch x86_64" "'"$WINE_SRC"'/configure" --enable-archs=x86_64 --disable-tests --without-x \
      --without-freetype --without-gnutls --without-sdl --without-vulkan --without-krb5 \
      --without-gstreamer --without-gphoto --without-sane --without-pcap --without-usb \
      --without-cups --without-coreaudio
  ' 2>&1 | tee "$BUILD_DIR/configure.log"
  [ -f "$WINE_BUILD/Makefile" ] || { echo "configure failed — see $BUILD_DIR/configure.log"; exit 1; }
  # CrossOver's win32u/vulkan.c uses SONAME_LIBVULKAN even with --without-vulkan; define it so it
  # compiles (dlopen fails gracefully at runtime).
  local cfg="$WINE_BUILD/include/config.h"
  sed -i '' 's|/\* #undef SONAME_LIBVULKAN \*/|#define SONAME_LIBVULKAN "libvulkan.1.dylib"|' "$cfg"
  sed -i '' 's|/\* #undef SONAME_LIBMOLTENVK \*/|#define SONAME_LIBMOLTENVK "libMoltenVK.dylib"|' "$cfg"
}

cmd_build() {
  # make pulls in the tools, headers and import libs these three need.
  local targets="dlls/ntdll/ntdll.so dlls/kernel32/x86_64-windows/kernel32.dll dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe"
  [ "${FULL:-0}" = "1" ] && targets=""
  log "Building ${targets:-the full tree} (make -j$JOBS)"
  [ -f "$WINE_BUILD/Makefile" ] || { echo "run 'configure' first"; exit 1; }
  arch -x86_64 /bin/bash -c '
    '"$TOOLCHAIN_ENV"'; export PATH="'"$("$BREW" --prefix bison)"'/bin:$PATH"
    cd "'"$WINE_BUILD"'" && make -j'"$JOBS"' '"$targets"'
  ' 2>&1 | tee "$BUILD_DIR/build.log"
  local rc=${PIPESTATUS[0]}
  [ "$rc" = 0 ] || { echo "make failed (exit $rc) — see $BUILD_DIR/build.log"; exit "$rc"; }
}

cmd_package() {
  local out="$DIST_DIR/$PKG_NAME" B="$WINE_BUILD"
  log "Packaging into $out.tar.gz"
  [ -f "$B/dlls/ntdll/ntdll.so" ] || { echo "run 'build' first"; exit 1; }
  rm -rf "$out" "$out.tar.gz" "$out.tar.gz.sha256"; mkdir -p "$out"
  cp "$B/dlls/ntdll/ntdll.so" \
     "$B/dlls/kernel32/x86_64-windows/kernel32.dll" \
     "$B/dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe" "$out/" || exit 1
  # CrossOver's ntdll dlopens cxcompatdb.so, which resolves @rpath/libgnutls through ntdll.so's own
  # LC_RPATH. CodeWeavers' ntdll carries @loader_path/../../../lib64; without it D3DMetal never
  # engages. Added here so installing needs no developer tools.
  install_name_tool -add_rpath "@loader_path/../../../lib64" "$out/ntdll.so" || exit 1
  cp "$WINE_SRC/COPYING.LIB" "$out/"
  echo "$CX_VER" > "$out/CROSSOVER_VERSION"
  local repo_url commit
  if [ -n "${GITHUB_REPOSITORY:-}" ]; then repo_url="${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY"
  else repo_url="$(git -C "$REPO" config --get remote.origin.url || echo unknown)"; fi
  commit="$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo unknown)"
  git -C "$REPO" diff --quiet HEAD -- patches scripts 2>/dev/null || commit="$commit (with uncommitted changes)"
  cat > "$out/SOURCE.txt" <<EOF
These modules are Wine, licensed LGPL-2.1-or-later (see COPYING.LIB). Built from:

  CrossOver $CX_VER source: $SRC_URL
  patches and build script: $repo_url
  commit:                   $commit
EOF
  ( cd "$out" && shasum -a 256 ntdll.so kernel32.dll ntoskrnl.exe > SHA256SUMS && cat SHA256SUMS )
  COPYFILE_DISABLE=1 tar -czf "$out.tar.gz" -C "$DIST_DIR" "$PKG_NAME" || exit 1
  ( cd "$DIST_DIR" && shasum -a 256 "$PKG_NAME.tar.gz" > "$PKG_NAME.tar.gz.sha256" )
  echo "packaged: $out.tar.gz"
}

case "${1:-all}" in
  deps|fetch|apply|configure|build|package) "cmd_$1" ;;
  all) cmd_deps; cmd_fetch; cmd_apply; cmd_configure; cmd_build; cmd_package ;;
  *) echo "usage: $0 [all|deps|fetch|apply|configure|build|package]"; exit 1 ;;
esac
