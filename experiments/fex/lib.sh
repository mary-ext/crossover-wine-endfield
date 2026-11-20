log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok(){  printf '  \033[32m✓\033[0m %s\n' "$*"; }
die(){ printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Paths shared by build-wine.sh, setup.sh and run.sh; REPO is set by the caller.
BUILD_DIR="${BUILD_DIR:-$REPO/build/fex}"
BOTTLE="${BOTTLE:-Endfield-FEX}"
APP="$BUILD_DIR/CrossOver FEX.app"
CXR="$APP/Contents/SharedSupport/CrossOver"
export CX_BOTTLE_PATH="$BUILD_DIR/bottles"
LLVM_MINGW=llvm-mingw-20260922-ucrt-macos-universal
TOOLCHAIN="$BUILD_DIR/$LLVM_MINGW/bin"

# check_sha FILE SHA256: an empty SHA256 skips the check.
check_sha(){ [ -z "$2" ] || echo "$2  $1" | shasum -a 256 -c -s || die "checksum mismatch: $1"; }

# input_path SOURCE CACHE: print SOURCE's local path, downloading URLs to CACHE if absent.
input_path() {
  case "$1" in
    http://*|https://*)
      if [ ! -f "$2" ]; then
        # Cache only complete downloads.
        curl -fL "$1" -o "$2.part" >&2 && mv "$2.part" "$2" || { rm -f "$2.part"; die "download failed: $1"; }
      fi
      printf '%s' "$2" ;;
    *) [ -f "$1" ] || die "not found: $1"; printf '%s' "$1" ;;
  esac
}
