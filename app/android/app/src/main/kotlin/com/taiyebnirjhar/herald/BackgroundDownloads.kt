package com.taiyebnirjhar.herald

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import java.io.File

/**
 * Every download in the app goes through here, so it keeps going when the app
 * is in the background or closed. Android's download manager does the work,
 * shows a notification, and resumes after network drops. The app asks for the
 * state by file name, so it works after the app has been restarted.
 */
class BackgroundDownloads(private val context: Context) {

    private val manager = context.getSystemService(DownloadManager::class.java)
    private val prefs = context.getSharedPreferences("downloads", Context.MODE_PRIVATE)

    private fun folder(): File =
        context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: context.filesDir

    /** Starts [url] as [name] (or reattaches to it if it is already running or done). */
    fun start(url: String, name: String, title: String, wifiOnly: Boolean): Map<String, Any?> {
        val known = prefs.getLong(name, -1L)
        val state = status(name)["state"] as String
        if (known >= 0 && DownloadReuse.shouldReuse(state, File(folder(), name).exists())) return status(name)
        if (known >= 0) manager.remove(known)
        File(folder(), name).delete()

        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, name)
        if (wifiOnly) request.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
        val id = manager.enqueue(request)
        prefs.edit().putLong(name, id).apply()
        return status(name)
    }

    /** The state of the download called [name]: running, waiting, done, failed or none. */
    fun status(name: String): Map<String, Any?> {
        val id = prefs.getLong(name, -1L)
        if (id < 0) return mapOf("state" to "none")
        manager.query(DownloadManager.Query().setFilterById(id)).use { c ->
            if (!c.moveToFirst()) return mapOf("state" to "none")
            // A finished download counts only while its file is still on the phone.
            val fileThere = File(folder(), name).exists()
            val status = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val bytes = c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            val total = c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            val reason = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            val state = when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> if (fileThere) "done" else "none"
                DownloadManager.STATUS_FAILED -> "failed"
                DownloadManager.STATUS_PAUSED -> "waiting"
                else -> "running"
            }
            if (state == "none") return mapOf("state" to "none")
            return mapOf(
                "state" to state,
                "bytes" to bytes,
                "total" to total,
                "path" to File(folder(), name).path,
                "reason" to if (state == "failed") "Download failed (code $reason)" else null,
            )
        }
    }
}
