package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Keeps Hermes's dashboard running (WBS 4.2 to 4.4): starts it inside the Linux
 * base, checks that it answers on 127.0.0.1:9119, and restarts it with backoff
 * if it stops. Hermes listens on loopback only (PLAN.md D7).
 */
class HermesSupervisor(private val context: Context, private val runtime: ProotRuntime) {

    private val logFile = File(context.filesDir, "runtime/hermes-run.log")

    /** Starts the supervisor loop on its own thread. Does nothing if it is already running. */
    fun start() {
        synchronized(lock) {
            if (running) return
            running = true
            stopRequested = false
        }
        Thread({ loop() }, "hermes-supervisor").start()
    }

    /** Stops Hermes and the loop. */
    fun stop() = requestStop()

    private fun loop() {
        val backoff = RestartBackoff()
        try {
            while (!stopRequested) {
                setPhase(Phase.STARTING, "Starting Hermes…")
                logFile.parentFile?.mkdirs()
                val started = System.currentTimeMillis()
                val child = runtime.startInGuest(dashboardCommand(installedWebDist()), logFile)
                synchronized(lock) { process = child }
                val health = Thread({ watchHealth(child) }, "hermes-health").apply { isDaemon = true }
                health.start()

                val code = child.waitFor()
                health.interrupt()
                if (stopRequested) break

                append("Hermes stopped (exit code $code).")
                if (System.currentTimeMillis() - started > HEALTHY_AFTER_MS) backoff.reset()
                if (backoff.giveUp) {
                    setPhase(Phase.GAVE_UP, "Hermes stopped five times in a row. Open the log for details.")
                    break
                }
                val wait = backoff.next()
                setPhase(Phase.RESTARTING, "Restarting Hermes in ${wait / 1000} s…")
                Thread.sleep(wait)
            }
        } catch (_: InterruptedException) {
            // stop() interrupted a wait.
        } finally {
            synchronized(lock) {
                running = false
                process = null
            }
            if (phase != Phase.GAVE_UP) setPhase(Phase.STOPPED, "Hermes is stopped.")
        }
    }

    /** Checks the dashboard port while [child] runs and reports ready or not. */
    private fun watchHealth(child: Process) {
        try {
            while (child.isAlive) {
                val answering = answers()
                if (answering && phase != Phase.READY) setPhase(Phase.READY, "Hermes is running.")
                if (!answering && phase == Phase.READY) setPhase(Phase.STARTING, "Hermes is not answering yet…")
                Thread.sleep(HEALTH_EVERY_MS)
            }
        } catch (_: InterruptedException) {
            // The process ended.
        }
    }

    /** The installed web UI, if the installer left it in the Linux base; otherwise null. */
    private fun installedWebDist(): String? =
        if (File(runtime.rootfsDir, "$WEB_DIST_IN_GUEST/index.html").exists()) WEB_DIST_IN_GUEST else null

    private fun answers(): Boolean = try {
        Socket().use { it.connect(InetSocketAddress(HOST, PORT), 1_000) }
        true
    } catch (_: IOException) {
        false
    }

    private fun append(line: String) {
        logFile.parentFile?.mkdirs()
        logFile.appendText(line + "\n")
    }

    private fun setPhase(next: Phase, text: String) {
        synchronized(lock) {
            phase = next
            message = text
        }
        onChange?.invoke(next)
    }

    companion object {
        const val HOST = "127.0.0.1"
        const val PORT = 9119
        private const val HEALTH_EVERY_MS = 2_000L
        private const val HEALTHY_AFTER_MS = 60_000L

        private val lock = Any()
        private var running = false
        private var stopRequested = false
        private var process: Process? = null

        @Volatile
        var phase: Phase = Phase.STOPPED
            private set

        @Volatile
        var message: String = "Hermes is stopped."
            private set

        /** Stops Hermes and its loop, from anywhere. */
        fun requestStop() {
            synchronized(lock) {
                stopRequested = true
                process?.destroyForcibly()
            }
        }

        /** Told each time the phase changes (the service uses it for its notification). */
        @Volatile
        var onChange: ((Phase) -> Unit)? = null

        enum class Phase { STOPPED, STARTING, READY, RESTARTING, GAVE_UP }

        /**
         * Where the installer puts the built web UI, as a path inside the Linux base.
         * Without it, the dashboard tries to build the UI on every start, and the phone has no npm.
         */
        const val WEB_DIST_IN_GUEST = "/usr/local/lib/hermes-agent/hermes_cli/web_dist"

        /**
         * The dashboard command, with a clean environment. Loopback only (PLAN.md D7).
         * With [webDist], Hermes is told where the built web UI is, so it does not rebuild it.
         */
        fun dashboardCommand(webDist: String? = null): List<String> = buildList {
            add("/usr/bin/env")
            add("-i")
            add("HOME=/root")
            add("PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin")
            add("LANG=C.UTF-8")
            if (webDist != null) add("HERMES_WEB_DIST=$webDist")
            addAll(
                listOf(
                    "/usr/local/bin/hermes", "dashboard",
                    "--host", HOST, "--port", PORT.toString(), "--no-open",
                ),
            )
        }
    }
}
