package com.taiyebnirjhar.herald

/**
 * How long to wait before restarting Hermes after a crash (WBS 4.4): 2 s, 4 s,
 * 8 s, 16 s, 32 s (capped at one minute), then give up. Matches the Dart copy in
 * lib/supervisor/restart_backoff.dart.
 */
class RestartBackoff(
    private val baseMs: Long = 2_000L,
    private val maxAttempts: Int = 5,
    private val capMs: Long = 60_000L,
) {
    var attempts: Int = 0
        private set

    val giveUp: Boolean get() = attempts >= maxAttempts

    /** The wait before the next restart. Throws if [giveUp]. */
    fun next(): Long {
        check(!giveUp) { "No more restarts: $maxAttempts tried." }
        val wait = baseMs shl attempts
        attempts++
        return minOf(wait, capMs)
    }

    /** Call when Hermes has been running for a while: the count starts again. */
    fun reset() {
        attempts = 0
    }
}
