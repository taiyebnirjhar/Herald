package com.taiyebnirjhar.herald

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Shows "a job finished" notifications on the "Agent results" channel (WBS 0.3.4).
 * Tapping one opens Herald. The text is plain words: the job name, never the prompt or the key.
 */
object JobNotifier {
    const val CHANNEL_ID = "agent_results"
    const val CHANNEL_NAME = "Agent results"

    /** Posts [run]. Android may refuse it (notifications off); that is not an error here. */
    fun show(context: Context, run: FinishedRun) {
        show(context, idFor(run.executionId), run.title, run.body)
    }

    /** Posts a notification with the given id, title and text. */
    fun show(context: Context, id: Int, title: String, body: String) {
        ensureChannel(context)
        // Tapping opens the scheduled jobs list (see Routes).
        val tap = Routes.pendingIntent(context, Routes.JOBS)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // Notifications are switched off for Herald. Nothing else to do.
        }
    }

    /** A stable id per run, so a run's notification is never shown twice on top of itself. */
    internal fun idFor(executionId: String): Int = executionId.hashCode() and 0x7fffffff

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
    }
}

/**
 * The Dart side's way to show a notification and to read and write the saved run state
 * ([JobRunStore]), on the "herald/notify" channel.
 */
class JobNotifyChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                val id = call.argument<Int>("id")
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                if (id == null || title == null || body == null) {
                    result.error("bad_args", "Missing notification text.", null)
                    return
                }
                JobNotifier.show(context, id, title, body)
                result.success(null)
            }
            "getNotified" -> {
                val jobId = call.argument<String>("jobId")
                if (jobId == null) {
                    result.error("bad_args", "Missing job id.", null)
                    return
                }
                result.success(JobRunStore(context).get(jobId))
            }
            "setNotified" -> {
                val jobId = call.argument<String>("jobId")
                val value = call.argument<String>("value")
                if (jobId == null || value == null) {
                    result.error("bad_args", "Missing job id or value.", null)
                    return
                }
                JobRunStore(context).set(jobId, value)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "herald/notify"
    }
}
