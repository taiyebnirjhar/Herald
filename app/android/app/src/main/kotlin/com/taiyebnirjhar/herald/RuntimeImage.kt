package com.taiyebnirjhar.herald

/**
 * The Linux base system (WBS 1.3). The app downloads it in the background the
 * first time the player installs it, and checks it against [SHA256] before
 * unpacking. Changing the image means changing these values in a new app release.
 */
object RuntimeImage {
    /** Where the phone downloads it from. */
    const val URL =
        "https://github.com/taiyebnirjhar/Herald/releases/download/runtime-v0.0.1/debian-trixie-arm64.tar.gz"

    /** SHA-256 of the image. Checked before anything is unpacked. */
    const val SHA256 = "4802af3f826731048ac47da5026eab2aee08b482fc42752ee57720ddb53a0b05"
}
