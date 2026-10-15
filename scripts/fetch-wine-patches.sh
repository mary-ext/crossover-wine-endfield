#!/usr/bin/env bash
# Fetch pinned Wine backports and dwproton patches. See patches/README.md for sources.
#
# Usage: scripts/fetch-wine-patches.sh

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://dawn.wine/dawn-winery/wine-dwproton/commit"
DEST="$REPO/patches/wine"

# _upstream commits, oldest first.
UPSTREAM=(
  6e5dbabb29 369bf27b42 6ba3e3879f b1e94e0178 0296568f3d 201b51143f be6af5dc5f 09096f6ec8
  a06a0fe4bd b26885115f a46bf63f56 a51f06c596 eeb572ad5c 8d73211e95 886e42e74b 1d477da5f0
  26becb3fff 7f360264f6 088787f0c1 f1685d56da 2d029d06ac f792ce8774 b85fe1dd06 b234077648
  b6d3197d03 2b43629122 244e4ece4a 09e74ef80a 70cada90c1 57fb6023a5 ec05f86e7f 9df8239146
  13a723a7cd 4684a38c10 bd8271ec03 f29142cbb1 fc1e81734c 265dc1c2c1 94b7c71919 6f6850a5d5
  e2298dbc41 ab39f8dcc3 d5e436399c
)

# _dw commits, oldest first. Omissions and adaptations are listed in patches/README.md.
DWPROTON=(2811893688 7a9f39b82a 58ef4a499c 09a9cb034e 593daa15ba 4acd1acf8a 84407729bf dac7007ad0)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Number patches in fetch order; derive filenames from their subjects.
name_patches() {
  python3 -I - "$@" <<'EOF'
import os, re, sys
for n, path in enumerate(sys.argv[1:], 1):
    subj = ""
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith("Subject:"):
            subj = line[8:].strip()
        elif subj and line.startswith(" "):
            subj += " " + line.strip()
        elif subj:
            break
    subj = re.sub(r"^\[PATCH[^\]]*\]\s*", "", subj)
    slug = re.sub(r"[^A-Za-z0-9._]+", "-", subj).strip(".-")[:52].rstrip(".-")
    os.rename(path, os.path.join(os.path.dirname(path), f"{n:04d}-{slug}.patch"))
EOF
}

# Replace each patch set only after all its downloads succeed.
fetch_set() {
  local dir="$1" sha
  local files=()
  shift
  mkdir "$work/$dir"
  for sha in "$@"; do
    # Retry transport errors too: dawn.wine rate limits can surface as curl error 56.
    curl -fsS --retry 6 --retry-delay 10 --retry-all-errors "$BASE/$sha.patch" -o "$work/$dir/$sha"
    files+=("$work/$dir/$sha")
  done
  name_patches "${files[@]}"
  rm -rf "$DEST/$dir"
  mv "$work/$dir" "$DEST/$dir"
  echo "$dir: $# fetched"
}

fetch_set upstream "${UPSTREAM[@]}"
fetch_set dwproton "${DWPROTON[@]}"
