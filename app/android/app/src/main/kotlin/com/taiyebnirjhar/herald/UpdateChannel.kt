package com.taiyebnirjhar.herald

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Herald's in-app update, on the Android side (see lib/update/):
 * - the installed version,
 * - whether Herald may install apps (Android asks once),
 * - opening Android's installer on a downloaded APK.
 *
 * Only files in the app's cache folder under "updates/" can be installed,
 * which is what file_paths.xml shares with the installer.
 */
class UpdateChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installedVersion" -> result.success(installedVersion())
            "canInstall" -> result.success(canInstall())
            "cacheDir" -> result.success(context.cacheDir.path)
            "install" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "No file given", null)
                } else {
                    result.success(install(path))
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun installedVersion(): Map<String, Any> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        @Suppress("DEPRECATION")
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode.toInt()
        } else {
            info.versionCode
        }
        return mapOf(
            "versionName" to (info.versionName ?: "unknown"),
            "versionCode" to code,
        )
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            context.packageManager.canRequestPackageInstalls()

    /** Returns "started", or "needs_permission" after opening the settings page. */
    private fun install(path: String): String {
        val file = File(path)
        require(ApkPaths.isInstallable(file, context.cacheDir)) {
            "The update file is not where it should be"
        }

        if (!canInstall()) {
            context.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            return "needs_permission"
        }

        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        context.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        return "started"
    }

    companion object {
        const val CHANNEL = "herald/app_update"
    }
}
