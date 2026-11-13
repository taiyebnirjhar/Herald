package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Runs proot (WBS 1.2): the program that gives Hermes a Linux userspace.
 * The binaries come from the app's native library folder (runtime/proot/).
 * The Linux base system (WBS 1.3) is downloaded in the background, then
 * unpacked under filesDir/runtime/ as proot's guest root.
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
        "linuxInstalled" to isLinuxInstalled(),
        "linuxDir" to rootfsDir.path,
        "freeMb" to RuntimeReset.freeBytes(context) / (1024 * 1024),
    )

    /** `proot --version`: the exit code and everything it printed. */
    fun version(): Map<String, Any?> = run(null, "--version")

    /** The Linux base is installed and is the version this app expects. */
    fun isLinuxInstalled(): Boolean =
        File(rootfsDir, "usr/bin/uname").exists() &&
            versionFile().takeIf { it.isFile }?.readText()?.trim() == RuntimeImage.VERSION

    private fun versionFile(): File = File(context.filesDir, "runtime/linux-version")

    /**
     * Unpacks the downloaded Linux base system at [archive], after checking it.
     * [progress] reports each stage. Blocks; call off the main thread.
     */
    fun installRootfs(archive: File, progress: RootfsInstaller.Progress): Map<String, Any?> = try {
        RootfsInstaller.verifyAndExtract(archive, RuntimeImage.SHA256, rootfsDir, progress)
        versionFile().apply { parentFile?.mkdirs() }.writeText(RuntimeImage.VERSION)
        archive.delete()
        mapOf("ok" to true, "path" to rootfsDir.path)
    } catch (e: IOException) {
        mapOf("ok" to false, "error" to (e.message ?: "The install failed"))
    }

    /** Starts [command] inside the Linux base and returns at once; output goes to [logTo]. Long-running. */
    fun startInGuest(command: List<String>, logTo: File): Process {
        val args = mutableListOf(proot.path, "-r", rootfsDir.path, "-w", "/", "-b", "/proc", "-b", "/dev")
        args += command
        val builder = ProcessBuilder(args)
            .redirectErrorStream(true)
            .redirectOutput(ProcessBuilder.Redirect.appendTo(logTo))
        builder.environment()["PROOT_LOADER"] = loader.path
        builder.environment()["PROOT_TMP_DIR"] = tmpDir.path
        return builder.start()
    }

    /** Removes the unpacked Linux base so it can be set up again. Blocks; call off the main thread. */
    fun repair(): Map<String, Any?> =
        if (RuntimeReset.repair(File(context.filesDir, "runtime"))) {
            mapOf("ok" to true)
        } else {
            mapOf("ok" to false, "error" to "Couldn't remove the Linux base. Try again.")
        }

    /** Removes the Linux base, its downloads and the install log. Blocks; call off the main thread. */
    fun reset(): Map<String, Any?> {
        val runtimeDir = File(context.filesDir, "runtime")
        val ok = RuntimeReset.reset(
            runtimeDir,
            File(context.cacheDir, "rootfs-download"),
            File(runtimeDir, "hermes-install.log"),
        )
        return if (ok) mapOf("ok" to true) else mapOf("ok" to false, "error" to "Couldn't remove everything. Try again.")
    }

    /** Runs `/usr/bin/uname -a` inside the Linux base system. Blocks; call off the main thread. */
    fun uname(): Map<String, Any?> {
        if (!File(rootfsDir, "usr/bin/uname").exists()) {
            return mapOf("ok" to false, "error" to "The Linux base system is not installed yet.")
        }
        return run(rootfsDir, "/usr/bin/uname", "-a")
    }

    /**
     * Runs [command] inside the Linux base. [fakeRoot] lets it act as root (for
     * apt and the Hermes installer). Output goes to [logTo] when given. Long
     * runs are fine: this waits for the process to finish. Call off the main thread.
     */
    fun runInGuest(command: List<String>, fakeRoot: Boolean, logTo: File?): Map<String, Any?> {
        if (!proot.isFile) {
            return mapOf("ok" to false, "error" to "libproot.so is missing from the app: ${proot.path}")
        }
        val args = mutableListOf(proot.path)
        if (fakeRoot) args += "-0"
        args += listOf("-r", rootfsDir.path, "-w", "/", "-b", "/proc", "-b", "/dev")
        args += command
        return try {
            val builder = ProcessBuilder(args).redirectErrorStream(true)
            builder.environment()["PROOT_LOADER"] = loader.path
            builder.environment()["PROOT_TMP_DIR"] = tmpDir.path
            if (logTo != null) builder.redirectOutput(ProcessBuilder.Redirect.appendTo(logTo))
            val process = builder.start()
            val output = if (logTo == null) process.inputStream.bufferedReader().readText().trim() else ""
            val code = process.waitFor()
            mapOf(
                "ok" to (code == 0),
                "exitCode" to code,
                "output" to output,
                "error" to if (code == 0) null else "The command stopped with exit code $code",
            )
        } catch (e: Exception) {
            mapOf("ok" to false, "error" to "${e.javaClass.simpleName}: ${e.message}")
        }
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
