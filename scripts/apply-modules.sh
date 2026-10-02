#!/usr/bin/env bash
# Install our packaged Wine and MoltenVK builds into a copy of CrossOver.
#
# Usage:  scripts/apply-modules.sh [MODULES_DIR]    (default: dist/endfield-wine-modules)
# Env:
#   SRC_APP   CrossOver to copy (default /Applications/CrossOver.app)
#   DEST_APP  patched copy to create, replacing any existing one (default /Applications/CrossOver_Endfield_Patch.app)
#   APP_NAME  name shown in the menu bar and Dock (default "CrossOver Endfield")
#   FORCE=1   apply even if the modules were built for a different CrossOver version

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODULES="${1:-$REPO/dist/endfield-wine-modules}"
SRC_APP="${SRC_APP:-/Applications/CrossOver.app}"
DEST_APP="${DEST_APP:-/Applications/CrossOver_Endfield_Patch.app}"
APP_NAME="${APP_NAME:-CrossOver Endfield}"
# Distinct ID for the patched app; keep the stock length for in-place binary replacement.
STOCK_ID=com.codeweavers.CrossOver
BUNDLE_ID=com.codeweavers.CXPatched
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
log(){  printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok(){   printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
die(){  printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Package files and their destinations in the supported CrossOver layout.
components=(ntdll.so kernel32.dll ntoskrnl.exe wineserver libMoltenVK.dylib)
paths=(
  lib/wine/x86_64-unix/ntdll.so
  lib/wine/x86_64-windows/kernel32.dll
  lib/wine/x86_64-windows/ntoskrnl.exe
  "CrossOver-Hosted Application/wineserver"
  lib64/libMoltenVK.dylib
)

check_inputs() {
  local f built app_ver
  log "Checking modules in $MODULES"
  for f in "${components[@]}" CROSSOVER_VERSION SHA256SUMS; do
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
}

copy_app() {
  log "Copying $SRC_APP -> $DEST_APP"
  rm -rf "$DEST_APP"
  # Exclude quarantine and Finder metadata that prevents signing.
  ditto --noextattr --noqtn "$SRC_APP" "$DEST_APP"
}

install_components() {
  local i
  log "Installing patched Wine and MoltenVK builds"
  for i in "${!components[@]}"; do
    cp "$MODULES/${components[$i]}" "$CXR/${paths[$i]}"
    ok "${components[$i]}"
  done
  chmod 755 "$CXR/CrossOver-Hosted Application/wineserver" # CI artifacts drop the exec bit
}

sign_components() {
  log "Signing patched Mach-O components"
  codesign --force --sign - "$CXR/lib/wine/x86_64-unix/ntdll.so"
  codesign --force --sign - "$CXR/lib64/libMoltenVK.dylib"
  codesign --force --sign - --options runtime --entitlements "$ents" \
    "$CXR/CrossOver-Hosted Application/wineserver"
}

rebrand_app() {
  local plist="$DEST_APP/Contents/Info.plist"
  log "Setting name \"$APP_NAME\" and bundle ID $BUNDLE_ID"
  plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$plist"
  plutil -replace CFBundleName -string "$APP_NAME" "$plist"
  plutil -replace CFBundleDisplayName -string "$APP_NAME" "$plist"
  # Prevent Sparkle from overwriting the patches. Install policy belongs in Info.plist;
  # update checks are disabled in user defaults below.
  plutil -replace SUAllowsAutomaticUpdates -bool NO "$plist"
}

migrate_prefs() {
  log "Updating $BUNDLE_ID preferences"
  if ! defaults read "$BUNDLE_ID" >/dev/null 2>&1 && defaults export "$STOCK_ID" "$work/prefs.plist" 2>/dev/null; then
    defaults import "$BUNDLE_ID" "$work/prefs.plist"
    ok "copied sign-in and settings from $STOCK_ID"
  fi
  defaults write "$BUNDLE_ID" SUEnableAutomaticChecks -bool false
  ok "automatic update checks disabled"
}

# Launchers find CrossOver by the bundle ID embedded in these templates.
patch_launcher_templates() {
  local name dir exe archive
  log "Pointing app launcher templates at $BUNDLE_ID"
  for name in "Menu Helper" "Bottle Helper"; do
    dir="$work/$name"
    exe="$dir/Contents/MacOS/$name"
    archive="$DEST_APP/Contents/Resources/$name.cpbz2"
    mkdir "$dir"
    ( cd "$dir" && bzip2 -dc "$archive" | cpio -idm --quiet )
    OLD="$STOCK_ID" NEW="$BUNDLE_ID" perl -0777 -pi -e \
      '$n += s/\0\Q$ENV{OLD}\E\0/\0$ENV{NEW}\0/g; END { exit !$n }' "$exe" \
      || die "$name: $STOCK_ID literal not found"
    # Sign outside the bundle: CrossOver rewrites Info.plist when creating launchers.
    mv "$exe" "$work/exe"
    codesign --force --sign - --preserve-metadata=identifier,entitlements,flags "$work/exe"
    mv "$work/exe" "$exe"
    ( cd "$dir" && find . | cpio -o --format odc --quiet ) | bzip2 > "$archive"
    ok "$name"
  done
  # Clear the migrated version to force launcher rebuilds from the patched templates.
  defaults delete "$BUNDLE_ID" LastHelperVersion 2>/dev/null || true
  ok "app launchers will rebuild on next launch"
}

# Re-sign the bundle: macOS can reject unsealed copies tagged with com.apple.provenance.
seal_app() {
  log "Signing app bundle"
  # ditto --noextattr can leave FinderInfo on the bundle directory.
  xattr -rd com.apple.FinderInfo "$DEST_APP" 2>/dev/null || true
  xattr -rd com.apple.ResourceFork "$DEST_APP" 2>/dev/null || true
  # Omit --deep to keep nested CodeWeavers signatures. Keep entitlements but drop the
  # hardened runtime: its library validation rejects those signatures under ad-hoc signing.
  codesign --force --sign - --preserve-metadata=entitlements --timestamp=none "$DEST_APP"
  codesign --verify --deep --strict "$DEST_APP" || die "bundle signature verification failed"
  ok "bundle signature valid"
}

register_app() {
  log "Registering $BUNDLE_ID with LaunchServices"
  "$LSREGISTER" -f "$DEST_APP"
  ok "registered"
}

check_inputs
CXR="$DEST_APP/Contents/SharedSupport/CrossOver"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Read the original wineserver's hardened-runtime entitlements before replacing it.
ents="$work/wineserver.entitlements"
codesign -d --xml --entitlements "$ents" \
  "$SRC_APP/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wineserver" \
  2>/dev/null || die "cannot read wineserver entitlements"

copy_app
install_components
sign_components
rebrand_app
migrate_prefs
patch_launcher_templates
seal_app
register_app

cat <<EOF

Created $DEST_APP

If macOS blocks it, choose "Open Anyway" in System Settings -> Privacy & Security.
EOF
