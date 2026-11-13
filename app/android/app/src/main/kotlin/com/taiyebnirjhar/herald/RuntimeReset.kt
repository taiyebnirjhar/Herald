package com.taiyebnirjhar.herald

import android.content.Context
import android.os.StatFs
import java.io.File

/**
 * Runtime maintenance (WBS 3.4, 3.6): free-space checks before a download, and
 * repair or reset of the Linux base and its Hermes install. Pure file work,
 * kept free of UI so it can be unit tested.
 */
object RuntimeReset {

    /** Free space the setup needs: the download plus its unpacked copy, with headroom. */
    const val LINUX_NEED_BYTES = 400L * 1024 * 1024

    /** Free space the Hermes install needs (Python and packages). */
    const val HERMES_NEED_BYTES = 2L * 1024 * 1024 * 1024

    /** Bytes free on the storage that holds the app's files. */
    fun freeBytes(context: Context): Long = StatFs(context.filesDir.path).availableBytes

    /** Removes the unpacked Linux base (and so Hermes inside it). The download cache is kept. */
    fun repair(runtimeDir: File): Boolean {
        val linux = File(runtimeDir, RootfsName)
        val staging = File(runtimeDir, "$RootfsName.new")
        staging.deleteRecursively()
        return linux.deleteRecursively()
    }

    /** Removes everything the runtime made: the Linux base, leftover downloads and the install log. */
    fun reset(runtimeDir: File, downloadsDir: File, logFile: File): Boolean {
        val ok = runtimeDir.deleteRecursively()
        downloadsDir.deleteRecursively()
        logFile.delete()
        return ok && !runtimeDir.exists()
    }

    const val RootfsName = "debian-trixie-arm64"
}
