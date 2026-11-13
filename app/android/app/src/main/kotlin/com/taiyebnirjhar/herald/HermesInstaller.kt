package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.io.IOException

/**
 * Installs Hermes Agent inside the Linux base (WBS 1.4), at the commit pinned in
 * runtime/HERMES_PIN. The installer script was downloaded in the background
 * first; this copies it into the guest and runs it as fake root, logging its
 * output, then checks `hermes --version`. Runs inside [HermesService].
 */
class HermesInstaller(private val context: Context, private val runtime: ProotRuntime) {

    private val rootfs: File get() = runtime.rootfsDir
    private val logFile = File(context.filesDir, "runtime/hermes-install.log")

    /** Runs the install from [script]. Blocks (can take a long time); call off the main thread. */
    fun install(script: File): Map<String, Any?> {
        if (!File(rootfs, "usr/bin/uname").exists()) {
            return finish(mapOf("ok" to false, "error" to "Install the Linux base first (1.3)."))
        }
        synchronized(lock) {
            if (running) return mapOf("ok" to false, "error" to "The install is already running.")
            running = true
            result = null
        }
        try {
            logFile.parentFile?.mkdirs()
            logFile.writeText("Preparing the install…\n")
            writeResolvConf()
            copyScript(script)
            // The base image is minimal: the installer needs curl, git and certificates.
            val tools = runtime.runInGuest(command = aptCommand(), fakeRoot = true, logTo = logFile)
            if (tools["ok"] != true) return finish(tools)
            val install = runtime.runInGuest(command = guestCommand(), fakeRoot = true, logTo = logFile)
            if (install["ok"] != true) return finish(install)
            val version = runtime.runInGuest(
                command = listOf("/usr/local/bin/hermes", "--version"),
                fakeRoot = false,
                logTo = null,
            )
            return finish(
                mapOf(
                    "ok" to (version["ok"] == true),
                    "output" to (version["output"] ?: ""),
                    "error" to version["error"],
                ),
            )
        } catch (e: IOException) {
            return finish(mapOf("ok" to false, "error" to (e.message ?: "The install failed")))
        }
    }

    /** Whether the install is running, the last lines of its log, and its result when done. */
    fun status(): Map<String, Any?> {
        val lines = if (logFile.isFile) logFile.readLines().takeLast(LOG_LINES) else emptyList()
        val (isRunning, done) = synchronized(lock) { running to result }
        return buildMap {
            put("running", isRunning)
            put("log", lines.joinToString("\n"))
            if (done != null) put("result", done)
        }
    }

    private fun finish(outcome: Map<String, Any?>): Map<String, Any?> {
        synchronized(lock) {
            running = false
            result = outcome
        }
        return outcome
    }

    // Name resolution inside the guest: Android's DNS isn't in the guest's files.
    private fun writeResolvConf() {
        val etc = File(rootfs, "etc").apply { mkdirs() }
        val resolv = File(etc, "resolv.conf")
        resolv.delete()
        resolv.writeText("nameserver 1.1.1.1\nnameserver 8.8.8.8\n")
    }

    private fun copyScript(script: File) {
        val target = File(rootfs, "root/hermes-install.sh")
        target.parentFile?.mkdirs()
        script.copyTo(target, overwrite = true)
    }

    companion object {
        private val lock = Any()
        private var running = false
        private var result: Map<String, Any?>? = null

        /** Commit from runtime/HERMES_PIN (tag v2026.9.24). Keep the two in step. */
        const val PIN_COMMIT = "f97608f178d1ffeca59860195ab7da295f7c8e5f"
        const val PINNED_INSTALLER =
            "https://raw.githubusercontent.com/NousResearch/hermes-agent/$PIN_COMMIT/scripts/install.sh"
        const val LOG_LINES = 40

        /** Installs the tools the Hermes installer needs (curl, git, certificates), in the guest. */
        fun aptCommand(): List<String> = listOf(
            "/usr/bin/env", "-i",
            "HOME=/root",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "DEBIAN_FRONTEND=noninteractive",
            "/bin/sh", "-c",
            // A stopped earlier install can leave dpkg half-done; finish that first.
            "dpkg --configure -a || true; apt-get update && apt-get install -y --no-install-recommends curl git ca-certificates xz-utils",
        )

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
