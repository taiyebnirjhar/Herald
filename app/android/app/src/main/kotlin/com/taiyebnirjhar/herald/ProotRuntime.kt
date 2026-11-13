package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Runs proot (WBS 1.2): the program that will give Hermes a Linux
 * userspace. The binaries come from the app's native library folder
 * (runtime/proot/, see its README), which Android lets the app run.
 *
 * Spike only for now: it runs `proot --version` and reports what happened.
 */
class ProotRuntime(private val context: Context) {

    private val libDir: File = File(context.applicationInfo.nativeLibraryDir)
    private val proot: File = File(libDir, "libproot.so")
    private val loader: File = File(libDir, "libproot_loader.so")
    private val tmpDir: File = File(context.cacheDir, "proot-tmp").apply { mkdirs() }

    /** Facts about the installed pieces, for the debug screen. */
    fun describe(): Map<String, Any> = mapOf(
        "nativeLibDir" to libDir.path,
        "prootExists" to proot.isFile,
        "prootExecutable" to proot.canExecute(),
        "prootSize" to proot.length(),
        "loaderExists" to loader.isFile,
        "tmpDir" to tmpDir.path,
    )

    /** `proot --version`: the exit code and everything it printed. */
    fun version(): Map<String, Any?> {
        if (!proot.isFile) {
            return mapOf("ok" to false, "error" to "libproot.so is missing from the app: ${proot.path}")
        }
        return try {
            val process = ProcessBuilder(proot.path, "--version")
                .redirectErrorStream(true)
                .apply {
                    environment()["PROOT_LOADER"] = loader.path
                    environment()["PROOT_TMP_DIR"] = tmpDir.path
                }
                .start()
            val output = process.inputStream.bufferedReader().readText().trim()
            val finished = process.waitFor(10, TimeUnit.SECONDS)
            if (!finished) {
                process.destroyForcibly()
                return mapOf("ok" to false, "error" to "proot did not answer within 10 seconds", "output" to output)
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
}
