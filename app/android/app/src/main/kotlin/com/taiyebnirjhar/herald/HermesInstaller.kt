package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * Installs Hermes Agent inside the Linux base (WBS 1.4), at the commit pinned in
 * runtime/HERMES_PIN. The official installer does the work; this runs it under
 * proot with a fake root, writes its output to a log, and checks `hermes --version`.
 */
class HermesInstaller(private val context: Context, private val runtime: ProotRuntime) {

    private val rootfs: File get() = runtime.rootfsDir
    private val logFile = File(context.filesDir, "runtime/hermes-install.log")

    @Volatile
    var running = false
        private set

    /** Runs the install. Blocks (can take a long time); call off the main thread. */
    fun install(): Map<String, Any?> {
        if (running) return mapOf("ok" to false, "error" to "The install is already running.")
        if (!File(rootfs, "usr/bin/uname").exists()) {
            return mapOf("ok" to false, "error" to "Install the Linux base first (1.3).")
        }
        running = true
        try {
            logFile.parentFile?.mkdirs()
            logFile.writeText("Preparing the install…\n")
            writeResolvConf()
            downloadInstaller()
            val result = runtime.runInGuest(
                command = guestCommand(),
                fakeRoot = true,
                logTo = logFile,
            )
            if (result["ok"] != true) return result
            val version = runtime.runInGuest(
                command = listOf("/usr/local/bin/hermes", "--version"),
                fakeRoot = false,
                logTo = null,
            )
            return mapOf(
                "ok" to (version["ok"] == true),
                "output" to (version["output"] ?: ""),
                "error" to version["error"],
            )
        } catch (e: IOException) {
            return mapOf("ok" to false, "error" to (e.message ?: "The install failed"))
        } finally {
            running = false
        }
    }

    /** The last lines of the install log, for the screen. */
    fun status(): Map<String, Any?> {
        val lines = if (logFile.isFile) logFile.readLines().takeLast(LOG_LINES) else emptyList()
        return mapOf("running" to running, "log" to lines.joinToString("\n"))
    }

    // Name resolution inside the guest: Android's DNS isn't in the guest's files.
    private fun writeResolvConf() {
        val etc = File(rootfs, "etc").apply { mkdirs() }
        val resolv = File(etc, "resolv.conf")
        resolv.delete()
        resolv.writeText("nameserver 1.1.1.1\nnameserver 8.8.8.8\n")
    }

    // The pinned installer (raw file at the pinned commit), so the install
    // script itself is the one we checked in runtime/HERMES_PIN.
    private fun downloadInstaller() {
        val target = File(rootfs, "root/hermes-install.sh")
        target.parentFile?.mkdirs()
        val conn = URL(PINNED_INSTALLER).openConnection() as HttpURLConnection
        conn.connectTimeout = 15_000
        conn.readTimeout = 60_000
        try {
            if (conn.responseCode != 200) {
                throw IOException("The Hermes installer download failed (answered ${conn.responseCode})")
            }
            conn.inputStream.use { input -> target.outputStream().use { input.copyTo(it) } }
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        /** Commit from runtime/HERMES_PIN (tag v2026.9.24). Keep the two in step. */
        const val PIN_COMMIT = "f97608f178d1ffeca59860195ab7da295f7c8e5f"
        const val PINNED_INSTALLER =
            "https://raw.githubusercontent.com/NousResearch/hermes-agent/$PIN_COMMIT/scripts/install.sh"
        const val LOG_LINES = 40

        /** The installer command, with a clean environment, run inside the guest. */
        fun guestCommand(): List<String> = listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "LANG=C.UTF-8",
            "DEBIAN_FRONTEND=noninteractive",
            "/bin/bash", "/root/hermes-install.sh",
            "--non-interactive", "--commit", PIN_COMMIT,
        )
    }
}
