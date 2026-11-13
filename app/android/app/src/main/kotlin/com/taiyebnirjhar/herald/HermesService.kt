package com.taiyebnirjhar.herald

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

/**
 * Runs the Hermes install in the foreground, so it keeps going with the app in
 * the background or the screen off. A notification shows it is running.
 */
class HermesService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val script = intent?.getStringExtra(EXTRA_SCRIPT)
        if (script == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        createChannel()
        val notification = notification("Installing Hermes Agent…")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        Thread({
            val outcome = HermesInstaller(this, ProotRuntime(this)).install(File(script))
            val done = notification(
                if (outcome["ok"] == true) "Hermes Agent is installed." else "The Hermes install stopped. Open Herald to see why.",
            )
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, done)
            stopForeground(STOP_FOREGROUND_DETACH)
            stopSelf()
        }, "hermes-install").start()
        return START_NOT_STICKY
    }

    private fun notification(text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Herald")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Setup", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    companion object {
        const val EXTRA_SCRIPT = "script"
        private const val CHANNEL = "setup"
        private const val NOTIFICATION_ID = 61

        /** Starts the install from the installer [script] file. */
        fun start(context: Context, script: File) {
            val intent = Intent(context, HermesService::class.java).putExtra(EXTRA_SCRIPT, script.path)
            context.startForegroundService(intent)
        }
    }
}
