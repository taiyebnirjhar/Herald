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

/**
 * Keeps Hermes running in the foreground (WBS 4.2): a notification shows its
 * state while the supervisor runs. The service stops when Hermes is stopped or
 * has given up.
 */
class SupervisorService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        val first = notification(HermesSupervisor.message)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, first, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, first)
        }
        HermesSupervisor.onChange = { phase ->
            getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification(HermesSupervisor.message))
            if (phase == HermesSupervisor.Companion.Phase.STOPPED || phase == HermesSupervisor.Companion.Phase.GAVE_UP) {
                JobRunPoller.stop()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        HermesSupervisor(this, ProotRuntime(this)).start()
        // Announces finished scheduled-job runs while Hermes runs (WBS 0.3.4).
        JobRunPoller.start(this)
        return START_NOT_STICKY
    }

    private fun notification(text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Herald")
            .setContentText(text)
            .setContentIntent(Routes.pendingIntent(this, Routes.CHAT))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Hermes", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    companion object {
        private const val CHANNEL = "hermes"
        private const val NOTIFICATION_ID = 62

        fun start(context: Context) {
            context.startForegroundService(Intent(context, SupervisorService::class.java))
        }
    }
}
