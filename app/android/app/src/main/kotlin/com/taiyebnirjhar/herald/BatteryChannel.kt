package com.taiyebnirjhar.herald

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Battery settings (WBS 4.6). Android may stop background apps to save battery.
 * These calls tell the screen whether Herald is allowed to run freely, let the
 * player allow it, and open the settings screens where it is switched on.
 *
 * Samsung's own battery screen is tried first. It may not exist on every model,
 * so the standard Android list and then Herald's app page are the fallbacks.
 */
class BatteryChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(mapOf("exempt" to isExempt()))
            "requestExemption" -> result.success(mapOf("opened" to open(requestIntent())))
            "openBatterySettings" -> result.success(mapOf("opened" to openFirst()))
            else -> result.notImplemented()
        }
    }

    /** True when Android does not stop Herald to save battery. */
    private fun isExempt(): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    /** Android's own question: "Allow Herald to run in the background?" */
    private fun requestIntent(): Intent =
        Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${context.packageName}"),
        )

    /** Tries each battery screen in turn; returns true when one opened. */
    private fun openFirst(): Boolean {
        val candidates = listOf(
            Intent().setComponent(
                ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            ),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")),
        )
        return candidates.any { open(it) }
    }

    /** Opens [intent] if this phone has a screen for it. */
    private fun open(intent: Intent): Boolean {
        if (intent.resolveActivity(context.packageManager) == null) return false
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return true
    }

    companion object {
        const val CHANNEL = "herald/battery"
    }
}
