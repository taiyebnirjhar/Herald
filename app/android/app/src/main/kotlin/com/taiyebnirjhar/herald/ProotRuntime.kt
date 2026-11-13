package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Runs proot (WBS 1.2): the program that gives Hermes a Linux userspace.
 * The binaries come from the app's native library folder (runtime/proot/).
 * The Linux base system (WBS 1.3) is installed under filesDir/runtime/ and
 * runs as proot's guest root.
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
    )

    /** `proot --version`: the exit code and everything it printed. */
    fun version(): Map<String, Any?> = run(null, "--version")

    /** Installs the Linux base system from [url], checked against [sha256]. Blocks; call off the main thread. */
    fun installRootfs(url: String, sha256: String): Map<String, Any?> = try {
        RootfsInstaller(rootfsDir).install(url, sha256, File(context.cacheDir, "rootfs-download")) {}
        mapOf("ok" to true, "path" to rootfsDir.path)
    } catch (e: IOException) {
        mapOf("ok" to false, "error" to (e.message ?: "The install failed"))
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
