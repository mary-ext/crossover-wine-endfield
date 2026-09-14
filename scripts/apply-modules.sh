#!/usr/bin/env bash
# apply-modules.sh — make a patched copy of CrossOver from packaged Endfield Wine modules.
#
# Copies CrossOver.app, swaps in ntdll.so / kernel32.dll / ntoskrnl.exe (keeping .cxorig backups),
# optionally installs Apple's GPTK D3DMetal, then ad-hoc signs the swapped files and removes the
# bundle seal and quarantine so they load. The original CrossOver.app is not modified.
#
# Usage:  scripts/apply-modules.sh [MODULES_DIR]    (default: dist/endfield-wine-modules)
# Env:
#   SRC_APP   CrossOver to copy (default /Applications/CrossOver.app)
#   DEST_APP  patched copy to create, replacing any existing one (default /Applications/CrossOver_Endfield_Patch.app)
#   GPTK      Apple Game Porting Toolkit to take D3DMetal from (optional): its .dmg, the mounted
#             volume, or its redist/lib/external directory
#   FORCE=1   apply even if the modules were built for a different CrossOver version

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODULES="${1:-$REPO/dist/endfield-wine-modules}"
SRC_APP="${SRC_APP:-/Applications/CrossOver.app}"
DEST_APP="${DEST_APP:-/Applications/CrossOver_Endfield_Patch.app}"
GPTK="${GPTK:-}"
log(){  printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok(){   printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
die(){  printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight
log "Checking modules in $MODULES"
for f in ntdll.so kernel32.dll ntoskrnl.exe CROSSOVER_VERSION SHA256SUMS; do
  [ -f "$MODULES/$f" ] || die "$MODULES/$f not found — run scripts/build-modules.sh or scripts/install-release.sh"
done
( cd "$MODULES" && shasum -a 256 -c -s SHA256SUMS ) || die "checksum mismatch in $MODULES"
ok "checksums match"

[ -d "$SRC_APP" ] || die "$SRC_APP not found"
case "$DEST_APP" in *.app) ;; *) die "DEST_APP must end in .app: $DEST_APP" ;; esac
[ "$DEST_APP" != "$SRC_APP" ] || die "DEST_APP must differ from SRC_APP"

built="$(cat "$MODULES/CROSSOVER_VERSION")"
app_ver="$(defaults read "$SRC_APP/Contents/Info" CFBundleVersion 2>/dev/null || echo unknown)"
case "$app_ver." in
  "$built".*) ok "CrossOver $app_ver matches the modules (built from $built source)" ;;
  *) if [ "${FORCE:-0}" = "1" ]; then warn "CrossOver $app_ver, but modules were built from $built source (FORCE=1)"
     else die "$SRC_APP is CrossOver $app_ver, but the modules were built from $built source. The Wine ABI must match (FORCE=1 to override)."; fi ;;
esac

d3dmetal_version(){ plutil -extract CFBundleShortVersionString raw "$1/D3DMetal.framework/Resources/Info.plist" 2>/dev/null || echo "(unknown version)"; }
gptk_src=""
if [ -n "$GPTK" ]; then
  gptk_root="$GPTK"
  if [ -f "$GPTK" ]; then   # a .dmg: mount it read-only for the duration of this script
    gptk_mnt="$(mktemp -d)"
    trap 'hdiutil detach "$gptk_mnt" -quiet 2>/dev/null; rmdir "$gptk_mnt" 2>/dev/null' EXIT
    hdiutil attach -readonly -nobrowse -noverify -mountpoint "$gptk_mnt" "$GPTK" >/dev/null </dev/null \
      || die "couldn't mount $GPTK"
    gptk_root="$gptk_mnt"
  fi
  for d in "$gptk_root/redist/lib/external" "$gptk_root"; do
    if [ -f "$d/libd3dshared.dylib" ] && [ -d "$d/D3DMetal.framework" ]; then gptk_src="$d"; break; fi
  done
  [ -n "$gptk_src" ] || die "no D3DMetal found in $GPTK (expected redist/lib/external/D3DMetal.framework)"
  ok "GPTK D3DMetal $(d3dmetal_version "$gptk_src") found"
fi

# ---------------------------------------------------------------- copy app
log "Copying $SRC_APP -> $DEST_APP"
rm -rf "$DEST_APP"
cp -a "$SRC_APP" "$DEST_APP"
CXR="$DEST_APP/Contents/SharedSupport/CrossOver"
ok "copied"

# ---------------------------------------------------------------- swap modules
log "Swapping in the patched Wine modules"
swap(){ # module  path-under-lib/wine
  local dst="$CXR/lib/wine/$2"
  [ -f "$dst" ] || die "$dst not found — is $SRC_APP really CrossOver?"
  cp "$dst" "$dst.cxorig"
  cp "$MODULES/$1" "$dst"
  ok "$2"
}
swap ntdll.so     x86_64-unix/ntdll.so
swap kernel32.dll x86_64-windows/kernel32.dll
swap ntoskrnl.exe x86_64-windows/ntoskrnl.exe
codesign --force --sign - "$CXR/lib/wine/x86_64-unix/ntdll.so"

# ---------------------------------------------------------------- GPTK (optional)
if [ -n "$gptk_src" ]; then
  log "Installing GPTK D3DMetal"
  DEST_GPTK="$CXR/lib64/apple_gptk/external"
  [ -d "$DEST_GPTK" ] || die "$DEST_GPTK not found in this CrossOver"
  cp -a "$DEST_GPTK" "$DEST_GPTK.cxorig"
  ditto "$gptk_src" "$DEST_GPTK"   # merges over CrossOver's copy
  codesign --force --sign - "$DEST_GPTK/libd3dshared.dylib" 2>/dev/null
  codesign --force --deep --sign - "$DEST_GPTK/D3DMetal.framework" 2>/dev/null
  ok "D3DMetal $(d3dmetal_version "$DEST_GPTK")"
fi

# ---------------------------------------------------------------- seal / quarantine
log "Removing bundle seal and quarantine"
rm -rf "$DEST_APP/Contents/_CodeSignature" "$DEST_APP/Contents/CodeResources"
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true
ok "done"

cat <<EOF

Created $DEST_APP

Next:
  1. Open it. macOS will refuse the first time ("damaged" / "blocked to protect your Mac"):
     go to System Settings -> Privacy & Security and click "Open Anyway".
  2. In the game launcher's graphics settings, choose DirectX 11 (Vulkan / DirectX 12 give a white screen).
EOF
