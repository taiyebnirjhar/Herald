package com.taiyebnirjhar.herald

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Runs when the phone finishes starting up. If the player left "Start after the
 * phone restarts" on and Hermes is installed, it starts the same supervisor the
 * Start button uses.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val installed = ProotRuntime(context).isLinuxInstalled() && BootStart.hermesInstalled(context)
        if (BootStart.shouldStart(BootStart.setting(context), installed)) {
            SupervisorService.start(context)
        }
    }
}
