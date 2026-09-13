#!/usr/bin/env bash
# install-release.sh — download prebuilt Endfield Wine modules from a GitHub release, verify them,
# and apply them to a copy of CrossOver with apply-modules.sh.
#
# Usage:  scripts/install-release.sh
# Env:
#   REPO      GitHub repository to download from (default mary-ext/crossover-wine-endfield)
#   TAG       release tag (default: the latest release)
#   BASE_URL  download from this URL instead of GitHub (expects the same asset names)
#   plus everything apply-modules.sh accepts: SRC_APP, DEST_APP, GPTK_DIR, FORCE

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="${REPO:-mary-ext/crossover-wine-endfield}"
TAG="${TAG:-}"
ASSET="endfield-wine-modules.tar.gz"
if [ -n "$TAG" ]; then base="https://github.com/$REPO/releases/download/$TAG"
else base="https://github.com/$REPO/releases/latest/download"; fi
base="${BASE_URL:-$base}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

printf '\n\033[1m==> Downloading %s\033[0m\n' "$base/$ASSET"
curl -fL --progress-bar -o "$work/$ASSET" "$base/$ASSET"
curl -fsSL -o "$work/$ASSET.sha256" "$base/$ASSET.sha256"
( cd "$work" && shasum -a 256 -c "$ASSET.sha256" )
tar -xzf "$work/$ASSET" -C "$work"
cat "$work/endfield-wine-modules/SOURCE.txt"

"$HERE/apply-modules.sh" "$work/endfield-wine-modules"
