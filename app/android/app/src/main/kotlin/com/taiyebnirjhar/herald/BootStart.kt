package com.taiyebnirjhar.herald

import android.content.Context
import java.nio.file.Files
import java.nio.file.LinkOption
import java.nio.file.Paths

/**
 * Start Hermes after the phone restarts (WBS 4.5).
 *
 * The player's switch lives in Settings (lib/settings/app_settings.dart), which
 * saves it through Flutter's shared preferences. Kotlin reads the same value.
 * Hermes starts only when the Linux base and Hermes are both installed.
 */
object BootStart {
    /** Flutter's shared preferences file, and the key Settings writes. */
    const val PREFS = "FlutterSharedPreferences"
    const val KEY = "flutter.herald.settings.boot_start"

    /** Same default as Settings: on. A missing value counts as on. */
    fun shouldStart(setting: Boolean?, hermesInstalled: Boolean): Boolean =
        (setting ?: true) && hermesInstalled

    /** The switch as the player left it, or null if they never changed it. */
    fun setting(context: Context): Boolean? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return if (prefs.contains(KEY)) prefs.getBoolean(KEY, true) else null
    }

    /**
     * Hermes is installed when its command exists inside the Linux base. The link is
     * not followed on the phone, because it points to a path inside the base.
     */
    fun hermesInstalled(context: Context): Boolean {
        val rootfs = ProotRuntime(context).rootfsDir
        val command = Paths.get(rootfs.path, "usr/local/bin/hermes")
        return Files.exists(command, LinkOption.NOFOLLOW_LINKS)
    }
}
