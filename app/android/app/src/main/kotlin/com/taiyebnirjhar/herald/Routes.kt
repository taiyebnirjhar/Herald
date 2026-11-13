package com.taiyebnirjhar.herald

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * The screens a notification can open in Herald. A route is only a short name
 * (never a prompt, a key or a job's text), so it is safe in an intent.
 *
 * [parse] and the names are plain Kotlin so they can be unit tested on the JVM.
 * The Dart side reads the same names (lib/navigation/notification_routes.dart).
 */
object Routes {
    /** The intent extra that carries the route name. */
    const val EXTRA = "herald.route"

    /** Setup: the Linux base and Hermes install screen. */
    const val SETUP = "setup"

    /** Scheduled jobs. */
    const val JOBS = "jobs"

    /** Native chat with Hermes. */
    const val CHAT = "chat"

    private val known = setOf(SETUP, JOBS, CHAT)

    /** The route for [value] when it is a known name, otherwise null. */
    fun parse(value: String?): String? = value?.takeIf { it in known }

    /** An intent that opens [MainActivity] on [route]. */
    fun intentFor(context: Context, route: String): Intent {
        require(route in known) { "Unknown route: $route" }
        return Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(EXTRA, route)
    }

    /**
     * A tap action for a notification that opens [route]. Each route has its own
     * request code, so two routes never share one pending intent.
     */
    fun pendingIntent(context: Context, route: String): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode(route),
            intentFor(context, route),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun requestCode(route: String): Int = "herald.route:$route".hashCode()
}
