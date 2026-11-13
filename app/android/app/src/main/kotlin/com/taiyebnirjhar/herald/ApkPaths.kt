package com.taiyebnirjhar.herald

import java.io.File

/**
 * Which files Herald may hand to Android's installer: only a `.apk` directly
 * inside the app's `updates/` cache folder. Kept free of Android types so it
 * can be unit tested on the JVM.
 */
object ApkPaths {
    /** The one folder the installer may read from (see res/xml/file_paths.xml). */
    const val UPDATES_FOLDER = "updates"

    fun isInstallable(file: File, cacheDir: File): Boolean {
        val allowedDir = File(cacheDir, UPDATES_FOLDER)
        return try {
            val canonical = file.canonicalFile
            canonical.parentFile == allowedDir.canonicalFile &&
                canonical.name.endsWith(".apk") &&
                canonical.isFile
        } catch (e: java.io.IOException) {
            false
        }
    }
}
