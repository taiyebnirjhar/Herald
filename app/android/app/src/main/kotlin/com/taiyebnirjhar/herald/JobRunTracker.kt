package com.taiyebnirjhar.herald

/**
 * One scheduled job and its newest run, as Hermes lists it (`GET /api/jobs`).
 * Holds no prompt text: [name] is already the safe display name.
 */
data class JobRunSnapshot(
    val jobId: String,
    val name: String,
    val executionId: String?,
    val status: String?,
)

/** A run that has finished and has not been announced yet. */
data class FinishedRun(
    val jobId: String,
    val name: String,
    val executionId: String,
    val status: String,
) {
    val title: String get() = JobRunTracker.title(status)
    val body: String get() = JobRunTracker.body(name, status)
}

/**
 * Decides which finished job runs are new, so each run is announced once (WBS 0.3.4).
 *
 * The state is one value per job: the id of the last run that was announced (or silently
 * accepted as already known). An empty value means "known, nothing announced yet".
 * Pure logic, no Android calls, so it is unit-tested on the JVM.
 */
object JobRunTracker {
    const val FALLBACK_NAME = "Scheduled job"
    private const val MAX_NAME = 60
    private val FINISHED = setOf("completed", "failed", "unknown")

    /** A run is finished once Hermes writes a final status. Running or claimed runs are not. */
    fun isFinished(status: String?): Boolean = status != null && status in FINISHED

    /**
     * The name to show. Hermes fills in a name from the prompt when a job has none, so a
     * name that is just the start of the prompt (or empty) is replaced by a plain fallback.
     */
    fun displayName(rawName: String, prompt: String): String {
        val name = clean(rawName)
        val text = clean(prompt)
        if (name.isEmpty() || (text.isNotEmpty() && text.startsWith(name))) return FALLBACK_NAME
        return if (name.length > MAX_NAME) name.take(MAX_NAME - 3) + "..." else name
    }

    fun title(status: String?): String = when (status) {
        "completed" -> "Job finished"
        "failed" -> "Job failed"
        else -> "Job ended unclearly"
    }

    fun body(name: String, status: String?): String = when (status) {
        "completed" -> "$name finished."
        "failed" -> "$name did not finish. Open Herald to see why."
        else -> "$name stopped before it could report a result."
    }

    /**
     * [notices] are the runs to announce now. [writes] are the state values to save, in
     * the same order as the decision. Save them before showing the notices, so a run is
     * never announced twice.
     */
    data class Decision(val notices: List<FinishedRun>, val writes: Map<String, String>)

    /**
     * [lastNotified] returns the saved value for a job, or null if the job was never seen.
     *
     * - Never seen: the first look is silent. A finished run is accepted as known; anything
     *   else is recorded as "nothing announced yet", so the run is announced when it finishes.
     * - Seen before: announce the newest run once, when it is finished and is not the one
     *   already announced.
     */
    fun decide(jobs: List<JobRunSnapshot>, lastNotified: (String) -> String?): Decision {
        val notices = mutableListOf<FinishedRun>()
        val writes = linkedMapOf<String, String>()
        for (job in jobs) {
            if (job.jobId.isEmpty()) continue
            val seen = lastNotified(job.jobId)
            val execution = job.executionId
            val done = isFinished(job.status) && execution != null
            if (seen == null) {
                writes[job.jobId] = if (done && execution != null) execution else ""
            } else if (done && execution != null && execution != seen) {
                notices += FinishedRun(job.jobId, job.name, execution, job.status ?: "")
                writes[job.jobId] = execution
            }
        }
        return Decision(notices, writes)
    }

    private fun clean(text: String): String = text.replace(Regex("\\s+"), " ").trim()
}
