#!/usr/bin/env bash
# Optional, for offline development only: puts the Linux base image into the app's
# assets so a local build bundles it. Release APKs do NOT bundle it: the app
# downloads it once on the phone (see RuntimeImage.kt). Not used by CI.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URL="https://github.com/taiyebnirjhar/Herald/releases/download/runtime-v0.0.1/debian-trixie-arm64.tar.gz"
SHA256="4802af3f826731048ac47da5026eab2aee08b482fc42752ee57720ddb53a0b05"
DEST="$ROOT/app/android/app/src/main/assets/runtime/linux-base.bin"
mkdir -p "$(dirname "$DEST")"
curl -sSfL -o "$DEST" "$URL"
echo "$SHA256  $DEST" | sha256sum -c -
echo "Bundled Linux image at $DEST (local builds only)"
