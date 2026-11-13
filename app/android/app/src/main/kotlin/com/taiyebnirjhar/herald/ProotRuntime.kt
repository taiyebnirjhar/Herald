package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Runs proot (WBS 1.2): the program that gives Hermes a Linux userspace.
 * The binaries come from the app's native library folder (runtime/proot/).
 * The Linux base system (WBS 1.3) is bundled in the APK and unpacked under
 * filesDir/runtime/ as proot's guest root.
 */
class ProotRuntime(private val context: Context) {

    private val libDir: File = File(context.applicationInfo.nativeLibraryDir)
    private val proot: File = File(libDir, "libproot.so")
    private val loader: File = File(libDir, "libproot_loader.so")
    private val tmpDir: File = File(context.cacheDir, "proot-tmp").apply { mkdirs() }

    /** The Linux base system: its guest root (what `/` is inside it). */
    val rootfsDir: File = File(context.filesDir, "runtime/$ROOTFS_NAME")

    /** Facts about the installed pieces, for the debug screen. */
    fun describe(): Map<String, Any> = mapOf(
        "nativeLibDir" to libDir.path,
        "prootExists" to proot.isFile,
        "prootExecutable" to proot.canExecute(),
        "prootSize" to proot.length(),
        "loaderExists" to loader.isFile,
        "tmpDir" to tmpDir.path,
        "linuxInstalled" to File(rootfsDir, "usr/bin/uname").exists(),
        "linuxDir" to rootfsDir.path,
        "linuxBundled" to isBundled(),
    )

    /** `proot --version`: the exit code and everything it printed. */
    fun version(): Map<String, Any?> = run(null, "--version")

    /** Whether the Linux image is bundled in this APK. */
    fun isBundled(): Boolean = try {
        context.assets.openFd(RuntimeImage.ASSET).use { true }
    } catch (e: IOException) {
        false
    }

    /**
     * Unpacks the Linux base system: from the copy bundled in the APK, or
     * downloaded if this build has none. [progress] reports each stage.
     * Blocks; call off the main thread.
     */
    fun installRootfs(progress: RootfsInstaller.Progress): Map<String, Any?> = try {
        val cache = File(context.cacheDir, "rootfs-download").apply { mkdirs() }
        val part = File(cache, "rootfs.tar.gz.part")
        part.delete()
        obtainImage(part, progress)
        RootfsInstaller.verifyAndExtract(part, RuntimeImage.SHA256, rootfsDir, progress)
        part.delete()
        mapOf("ok" to true, "path" to rootfsDir.path)
    } catch (e: IOException) {
        mapOf("ok" to false, "error" to (e.message ?: "The install failed"))
    }

    private fun obtainImage(part: File, progress: RootfsInstaller.Progress) {
        if (isBundled()) {
            context.assets.openFd(RuntimeImage.ASSET).use { fd ->
                fd.createInputStream().use { input ->
                    RootfsInstaller.copy(input, part, fd.length) { f -> progress("Copying the Linux image", f) }
                }
            }
        } else {
            download(RuntimeImage.URL, part) { f -> progress("Downloading the Linux image", f) }
        }
    }

    private fun download(url: String, to: File, onFraction: (Double) -> Unit) {
        val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
        conn.connectTimeout = 15_000
        conn.readTimeout = 60_000
        try {
            if (conn.responseCode != 200) throw IOException("The Linux image download failed (answered ${conn.responseCode})")
            conn.inputStream.use { input -> RootfsInstaller.copy(input, to, conn.contentLengthLong, onFraction) }
        } finally {
            conn.disconnect()
        }
    }

    /** Runs `/usr/bin/uname -a` inside the Linux base system. Blocks; call off the main thread. */
    fun uname(): Map<String, Any?> {
        if (!File(rootfsDir, "usr/bin/uname").exists()) {
            return mapOf("ok" to false, "error" to "The Linux base system is not installed yet.")
        }
        return run(rootfsDir, "/usr/bin/uname", "-a")
    }

    /** Runs proot with [rootfs] as the guest root (or none, for `--version`). */
    private fun run(rootfs: File?, vararg command: String): Map<String, Any?> {
        if (!proot.isFile) {
            return mapOf("ok" to false, "error" to "libproot.so is missing from the app: ${proot.path}")
        }
        val args = mutableListOf(proot.path)
        if (rootfs != null) args += listOf("-r", rootfs.path, "-w", "/")
        args += command
        return try {
            val process = ProcessBuilder(args)
                .redirectErrorStream(true)
                .apply {
                    environment()["PROOT_LOADER"] = loader.path
                    environment()["PROOT_TMP_DIR"] = tmpDir.path
                }
                .start()
            val output = process.inputStream.bufferedReader().readText().trim()
            val finished = process.waitFor(20, TimeUnit.SECONDS)
            if (!finished) {
                process.destroyForcibly()
                return mapOf("ok" to false, "error" to "proot did not answer within 20 seconds", "output" to output)
            }
            mapOf(
                "ok" to (process.exitValue() == 0),
                "exitCode" to process.exitValue(),
                "output" to output,
            )
        } catch (e: Exception) {
            // Typical here: the loader cannot start the program on this phone.
            mapOf("ok" to false, "error" to "${e.javaClass.simpleName}: ${e.message}")
        }
    }

    companion object {
        const val ROOTFS_NAME = "debian-trixie-arm64"
    }
}
