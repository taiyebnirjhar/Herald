# proot runtime pieces (WBS 1.1)

Used to run a Linux userspace (Debian) inside the app without root.

## What is here

`jniLibs/arm64-v8a/` holds four files. The build puts them in the app's native library folder,
where Android lets the app run them:

| File | From | Notes |
| --- | --- | --- |
| `libproot.so` | Termux `proot` 5.1.107.102 (aarch64) | Runs the Linux environment. `NEEDED` and `RUNPATH` patched to load its neighbours. |
| `libproot_loader.so` | Termux `proot` 5.1.107.102 (`libexec/proot/loader`) | Helper used by proot. Found through `PROOT_LOADER`. |
| `libtalloc.so` | Termux `libtalloc` 2.5.0 (aarch64) | SONAME changed to `libtalloc.so`, `RUNPATH` set to `$ORIGIN`. |
| `libandroid-shmem.so` | Termux `libandroid-shmem` 0.7 (aarch64) | `RUNPATH` set to `$ORIGIN`. |

Original packages (from `https://packages.termux.dev/apt/termux-main`, checked by SHA-256 from its index):

- `pool/main/p/proot/proot_5.1.107.102_aarch64.deb`, sha256 `10a394b585c2fc2b2c8502544f4e5f1be581dc8bfff79e8ba62f16207423e030`
- `pool/main/libt/libtalloc/libtalloc_2.5.0_aarch64.deb`, sha256 `556591f43bb773ad8777e1a29522640866a55f95dab71914418b94a8c58ad5a7`
- `pool/main/liba/libandroid-shmem/libandroid-shmem_0.7_aarch64.deb`, sha256 `0da3a24d558b93c92bcf8d611e0826a99ff96e396b148e6cdf33b47c47c57ff6`

The patched files' hashes are in `SHA256SUMS.patched`.

## Licences

- proot: GPL-2.0-or-later (`licenses/GPL-2.0.txt`, `licenses/GPL-3.0.txt`)
- libtalloc: LGPL-3.0 (`licenses/LGPL-3.0.txt`)
- libandroid-shmem: see the Termux package

Source: the Termux packages above link to their source. The app's "Open-source licences" screen will
link to them too (WBS 5.6).

## Patching

The patches are `patchelf --replace-needed`, `--set-rpath '$ORIGIN'`, and `--set-soname` (see the
commands in `tools/patch-proot.sh`). Rebuild them from the original packages when Termux updates.
