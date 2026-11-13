package com.taiyebnirjhar.herald

import android.content.Context
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Whether the Herald screen is in front. The Dart side announces results then, not this poller. */
object AppVisibility {
    @Volatile
    var resumed: Boolean = false
}

/**
 * Checks Hermes's scheduled jobs every minute while Hermes runs, and announces finished runs
 * (WBS 0.3.4). It works with the screen off, because the foreground service keeps it alive.
 * While the app is open, the Dart side does the same job, so this poller stays quiet then.
 * Both sides share one saved state ([JobRunStore]), so a run is announced once.
 */
object JobRunPoller {
    private const val EVERY_MS = 60_000L
    private const val CONNECT_MS = 5_000
    private const val READ_MS = 10_000

    private val lock = Any()
    private var thread: Thread? = null

    /** Starts the poller if it is not running. Calling it again does nothing. */
    fun start(context: Context) {
        val app = context.applicationContext
        synchronized(lock) {
            if (thread?.isAlive == true) return
            thread = Thread({ loop(app) }, "job-run-poller").apply {
                isDaemon = true
                start()
            }
        }
    }

    /** Stops the poller. Hermes has stopped, so there is nothing to check. */
    fun stop() {
        synchronized(lock) {
            thread?.interrupt()
            thread = null
        }
    }

    private fun loop(context: Context) {
        try {
            while (true) {
                if (!AppVisibility.resumed &&
                    HermesSupervisor.phase == HermesSupervisor.Companion.Phase.READY
                ) {
                    // A bad answer or a full disk must not stop the next check.
                    try {
                        checkOnce(context)
                    } catch (_: Exception) {
                        // Try again in a minute.
                    }
                }
                Thread.sleep(EVERY_MS)
            }
        } catch (_: InterruptedException) {
            // stop() ended the loop.
        }
    }

    /** One check: fetch the jobs, decide what is new, save the state, then announce. */
    internal fun checkOnce(context: Context): Int {
        val key = ApiKey.load(context)
        val body = fetchJobs(Engine.GATEWAY.port, key) ?: return 0
        val jobs = parseJobs(body)
        val store = JobRunStore(context)
        val decision = JobRunTracker.decide(jobs) { store.get(it) }
        decision.writes.forEach { (jobId, value) -> store.set(jobId, value) }
        decision.notices.forEach { JobNotifier.show(context, it) }
        return decision.notices.size
    }

    /** The response body, or null when Hermes did not answer with a success. The key is only sent as a header. */
    private fun fetchJobs(port: Int, key: String): String? {
        val connection = URL("http://${HermesSupervisor.HOST}:$port/api/jobs?include_disabled=true")
            .openConnection() as HttpURLConnection
        return try {
            connection.connectTimeout = CONNECT_MS
            connection.readTimeout = READ_MS
            connection.setRequestProperty("Authorization", "Bearer $key")
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                null
            } else {
                connection.inputStream.bufferedReader().use { it.readText() }
            }
        } catch (_: IOException) {
            null
        } finally {
            connection.disconnect()
        }
    }

    /** Reads `{"jobs": [...]}` from Hermes. Each job keeps only its id, safe name and newest run. */
    fun parseJobs(body: String): List<JobRunSnapshot> {
        val jobs = JSONObject(body).optJSONArray("jobs") ?: return emptyList()
        return (0 until jobs.length())
            .mapNotNull { jobs.optJSONObject(it) }
            .map { snapshot(it) }
            .filter { it.jobId.isNotEmpty() }
    }

    private fun snapshot(job: JSONObject): JobRunSnapshot {
        val execution = job.optJSONObject("latest_execution")
        return JobRunSnapshot(
            jobId = job.optString("id"),
            name = JobRunTracker.displayName(job.optString("name"), job.optString("prompt")),
            executionId = execution?.optString("id")?.takeIf { it.isNotEmpty() },
            status = execution?.optString("status")?.takeIf { it.isNotEmpty() },
        )
    }
}

/**
 * The saved "last announced run" for each job. Kept in the app's own SharedPreferences.
 * The Dart side reads and writes it through [JobNotifyChannel].
 */
class JobRunStore(context: Context) {
    private val prefs = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun get(jobId: String): String? = prefs.getString(KEY_PREFIX + jobId, null)

    fun set(jobId: String, value: String) {
        prefs.edit().putString(KEY_PREFIX + jobId, value).apply()
    }

    companion object {
        const val FILE = "job_runs"
        const val KEY_PREFIX = "notified:"
    }
}
