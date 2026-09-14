#!/usr/bin/env bash
# Fetch Endfield's dw-proton patches into patches/stage2-dwproton.
#
# Default: b816be489 (GE issue #433). Override with DWPROTON_SHA.
# The GitHub mirror shares dawn.wine's git objects and avoids its anti-bot wall.
#
# Usage: scripts/fetch-dwproton-patches.sh   (run from repo root)

set -uo pipefail
SHA="${DWPROTON_SHA:-b816be489049a10453b470c6a12dcf552ea41773}"
REPO="dawn-winery/dwproton-mirror"
BASE="https://raw.githubusercontent.com/${REPO}/${SHA}/patches/wine"
DEST="patches/stage2-dwproton"

mkdir -p "$DEST/misc" "$DEST/em-backports"
echo "Fetching dw-proton patches from ${REPO}@${SHA:0:12}"

# Dispatcher spoof, QPC waits and wintrust bypass (unused on macOS).
for p in \
  0002-misc/0008-wintrust-Prevent-checking-if-winex11-winewayland-are.patch \
  0002-misc/0009-HACK-kernel32-Spoof-GetProcAddress-of-KiUserApcDispa.patch \
  0002-misc/0010-HACK-kernel32-Lock-GetProcAddress-hack-to-when-neede.patch \
  0002-misc/0011-ntdll-Implement-NtDelayExecution-relative-wait-using.patch ; do
  curl -fsS "$BASE/$p" -o "$DEST/misc/$(basename "$p")" && echo "  ok  misc/$(basename "$p")" || echo "  FAIL $p"
done

# Fetch all em-backports (0001-0017 at the default commit).
curl -s "https://api.github.com/repos/${REPO}/git/trees/${SHA}?recursive=1" \
 | python3 -c "
import json,sys
for e in json.load(sys.stdin).get('tree',[]):
    p=e['path']
    if p.startswith('patches/wine/0003-em-backports/') and p.endswith('.patch'): print(p)
" | while IFS= read -r p; do
  curl -fsS "$BASE/${p#patches/wine/}" -o "$DEST/em-backports/$(basename "$p")" \
    && echo "  ok  em-backports/$(basename "$p")" || echo "  FAIL $p"
done

echo ""
echo "Patches: misc=$(ls -1 "$DEST/misc" 2>/dev/null | wc -l | tr -d ' ')  em-backports=$(ls -1 "$DEST/em-backports" 2>/dev/null | wc -l | tr -d ' ')"
echo "Newer changes are in dawn.wine/dawn-winery/wine-dwproton, branch 'base'."
