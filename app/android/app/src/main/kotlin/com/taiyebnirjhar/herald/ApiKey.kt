package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.security.SecureRandom

/**
 * The key the native chat uses to talk to Hermes's API server on 127.0.0.1 (WBS 6.2).
 * Made once on the phone, kept in the app's private folder, and never sent anywhere.
 * Hermes refuses to start its API server with a key shorter than 16 characters.
 */
object ApiKey {
    private const val FILE = "runtime/api-server-key"

    /** The saved key, or a new one if none is saved yet (or the saved one is too short). */
    fun load(context: Context): String {
        val file = File(context.filesDir, FILE)
        if (file.exists()) {
            val saved = file.readText().trim()
            if (saved.length >= MIN_LENGTH) return saved
        }
        val key = generate()
        file.parentFile?.mkdirs()
        file.writeText(key)
        // Only this app may read it.
        file.setReadable(false, false)
        file.setReadable(true, true)
        file.setWritable(false, false)
        file.setWritable(true, true)
        return key
    }

    /** 48 random hex characters. */
    internal fun generate(random: SecureRandom = SecureRandom()): String =
        ByteArray(24).also { random.nextBytes(it) }.joinToString("") { "%02x".format(it) }

    const val MIN_LENGTH = 16
}
