#!/usr/bin/env bash
# Install packaged Wine modules and MoltenVK into a copy of CrossOver.
#
# Usage:  scripts/apply-modules.sh [MODULES_DIR]    (default: dist/endfield-wine-modules)
# Env:
#   SRC_APP   CrossOver to copy (default /Applications/CrossOver.app)
#   DEST_APP  patched copy to create, replacing any existing one (default /Applications/CrossOver_Endfield_Patch.app)
#   FORCE=1   apply even if the modules were built for a different CrossOver version

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODULES="${1:-$REPO/dist/endfield-wine-modules}"
SRC_APP="${SRC_APP:-/Applications/CrossOver.app}"
DEST_APP="${DEST_APP:-/Applications/CrossOver_Endfield_Patch.app}"
log(){  printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok(){   printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
die(){  printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

log "Checking modules in $MODULES"
for f in ntdll.so kernel32.dll ntoskrnl.exe libMoltenVK.dylib CROSSOVER_VERSION SHA256SUMS; do
  [ -f "$MODULES/$f" ] || die "$MODULES/$f not found — run scripts/install-release.sh or follow README.md's source build steps"
done
( cd "$MODULES" && shasum -a 256 -c -s SHA256SUMS ) || die "checksum mismatch in $MODULES"
ok "checksums match"

[ -d "$SRC_APP" ] || die "$SRC_APP not found"
case "$DEST_APP" in *.app) ;; *) die "DEST_APP must end in .app: $DEST_APP" ;; esac
[ "$DEST_APP" != "$SRC_APP" ] || die "DEST_APP must differ from SRC_APP"

built="$(cat "$MODULES/CROSSOVER_VERSION")"
app_ver="$(defaults read "$SRC_APP/Contents/Info" CFBundleVersion 2>/dev/null || echo unknown)"
case "$app_ver." in
  "$built".*) ok "CrossOver $app_ver matches module version $built" ;;
  *) if [ "${FORCE:-0}" = "1" ]; then warn "CrossOver $app_ver; modules require $built (overridden by FORCE=1)"
     else die "$SRC_APP is CrossOver $app_ver; modules require $built for ABI compatibility (FORCE=1 to override)."; fi ;;
esac

mvk_version(){ LC_ALL=C tr '\0' '\n' < "$1" | LC_ALL=C awk '!v && /^[0-9]+\.[0-9]+\.[0-9]+$/ { v = $0 } END { print (v ? v : "(unknown version)") }'; }
mvk_src="$MODULES/libMoltenVK.dylib"
mvk_type="$(file -b "$mvk_src")"
case "$mvk_type" in
  *"dynamically linked shared library x86_64"*) ;;
  *) die "$mvk_src is not an x86_64 dynamic library: $mvk_type" ;;
esac
[ -f "$SRC_APP/Contents/SharedSupport/CrossOver/lib64/libMoltenVK.dylib" ] \
  || die "$SRC_APP has no lib64/libMoltenVK.dylib to replace"
ok "MoltenVK $(mvk_version "$mvk_src") found"

log "Copying $SRC_APP -> $DEST_APP"
rm -rf "$DEST_APP"
cp -a "$SRC_APP" "$DEST_APP"
CXR="$DEST_APP/Contents/SharedSupport/CrossOver"

log "Installing patched Wine modules"
swap(){ # module  path-under-lib/wine
  local dst="$CXR/lib/wine/$2"
  [ -f "$dst" ] || die "Wine module missing: $dst"
  cp "$dst" "$dst.cxorig"
  cp "$MODULES/$1" "$dst"
  ok "$2"
}
swap ntdll.so     x86_64-unix/ntdll.so
swap kernel32.dll x86_64-windows/kernel32.dll
swap ntoskrnl.exe x86_64-windows/ntoskrnl.exe
codesign --force --sign - "$CXR/lib/wine/x86_64-unix/ntdll.so"

log "Installing MoltenVK"
DEST_MVK="$CXR/lib64/libMoltenVK.dylib"
[ -f "$DEST_MVK" ] || die "$DEST_MVK not found in this CrossOver"
cp "$DEST_MVK" "$DEST_MVK.cxorig"
cp "$mvk_src" "$DEST_MVK"
codesign --force --sign - "$DEST_MVK"
ok "MoltenVK $(mvk_version "$DEST_MVK") (was $(mvk_version "$DEST_MVK.cxorig"))"

log "Removing bundle seal and quarantine"
rm -rf "$DEST_APP/Contents/_CodeSignature" "$DEST_APP/Contents/CodeResources"
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true

cat <<EOF

Created $DEST_APP

Open the app. If macOS blocks it, choose "Open Anyway" in System Settings -> Privacy & Security.
Enable MSync in the bottle's advanced settings.
EOF
