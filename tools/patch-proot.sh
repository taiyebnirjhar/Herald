#!/usr/bin/env bash
# Rebuilds runtime/proot/jniLibs/arm64-v8a from the Termux packages named in runtime/proot/README.md.
# Needs: ar, tar, patchelf, readelf, sha256sum, curl.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${1:-$(mktemp -d)}"
BASE=https://packages.termux.dev/apt/termux-main
OUT="$ROOT/runtime/proot/jniLibs/arm64-v8a"

fetch() { # url sha256 dest
  curl -sSf -o "$3" "$1"
  echo "$2  $3" | sha256sum -c --quiet
}

cd "$WORK"
fetch "$BASE/pool/main/p/proot/proot_5.1.107.102_aarch64.deb" 10a394b585c2fc2b2c8502544f4e5f1be581dc8bfff79e8ba62f16207423e030 proot.deb
fetch "$BASE/pool/main/libt/libtalloc/libtalloc_2.5.0_aarch64.deb" 556591f43bb773ad8777e1a29522640866a55f95dab71914418b94a8c58ad5a7 libtalloc.deb
fetch "$BASE/pool/main/liba/libandroid-shmem/libandroid-shmem_0.7_aarch64.deb" 0da3a24d558b93c92bcf8d611e0826a99ff96e396b148e6cdf33b47c47c57ff6 shmem.deb

for d in proot libtalloc shmem; do mkdir -p "x_$d"; (cd "x_$d" && ar x "../$d.deb" && tar -xf data.tar.*); done
P=data/data/com.termux/files/usr

mkdir -p "$OUT"
cp "x_proot/$P/bin/proot" "$OUT/libproot.so"
cp "x_proot/$P/libexec/proot/loader" "$OUT/libproot_loader.so"
cp "x_libtalloc/$P/lib/libtalloc.so.2.5.0" "$OUT/libtalloc.so"
cp "x_shmem/$P/lib/libandroid-shmem.so" "$OUT/libandroid-shmem.so"

cd "$OUT"
patchelf --replace-needed libtalloc.so.2 libtalloc.so libproot.so
patchelf --set-rpath '$ORIGIN' libproot.so
patchelf --set-soname libtalloc.so libtalloc.so
patchelf --set-rpath '$ORIGIN' libtalloc.so
patchelf --set-rpath '$ORIGIN' libandroid-shmem.so
sha256sum *.so > "$ROOT/runtime/proot/SHA256SUMS.patched"
echo "Rebuilt proot pieces in $OUT"
