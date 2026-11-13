package com.taiyebnirjhar.herald

/**
 * The Linux base system (WBS 1.3). It is bundled in the APK under assets/, so
 * the phone needs no download. CI puts the file there from the runtime release
 * and checks it against [SHA256] before building (see .github/workflows/app.yml).
 * Changing the image means changing these values in a new release.
 */
object RuntimeImage {
    /** Where the image is asset-bundled in the APK. */
    const val ASSET = "runtime/linux-base.bin"

    /** Where it can be downloaded if the bundled copy is missing (local dev builds). */
    const val URL =
        "https://github.com/taiyebnirjhar/Herald/releases/download/runtime-v0.0.1/debian-trixie-arm64.tar.gz"

    /** SHA-256 of the image. Checked before anything is unpacked. */
    const val SHA256 = "4802af3f826731048ac47da5026eab2aee08b482fc42752ee57720ddb53a0b05"
}
