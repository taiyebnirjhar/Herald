package com.taiyebnirjhar.herald

/**
 * The Linux base system (WBS 1.3). The app downloads it in the background the
 * first time the player installs it, and checks it against [SHA256] before
 * unpacking. Changing the image means changing these values in a new app release.
 */
object RuntimeImage {
    /** The image's version. A phone with another version sets the base up again. */
    const val VERSION = "runtime-v0.0.2"

    /** Where the phone downloads it from. */
    const val URL =
        "https://github.com/taiyebnirjhar/Herald/releases/download/runtime-v0.0.2/debian-trixie-arm64.tar.gz"

    /** SHA-256 of the image. Checked before anything is unpacked. */
    const val SHA256 = "d2366403876378d246de957dd26eb4b4358d87d1b621ba138365b5ed574d41b5"
}
