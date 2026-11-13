package com.taiyebnirjhar.herald

import android.content.Context
import java.io.File
import java.security.SecureRandom

/**
 * The key and port the native chat uses to talk to Hermes's API server on 127.0.0.1 (WBS 6.2).
 * Both are made once on the phone and kept in the app's private folder; neither is sent anywhere.
 * The port is random per install, so another app cannot guess it. Hermes refuses to start its
 * API server with a key shorter than 16 characters.
 */
object ApiKey {
    private const val FILE = "runtime/api-server-key"
    private const val PORT_FILE = "runtime/api-server-port"
    private const val PORT_LOW = 20_000
    private const val PORT_HIGH = 59_999

    /** The saved key, or a new one if none is saved yet (or the saved one is too short). */
    @Synchronized
    fun load(context: Context): String {
        val file = File(context.filesDir, FILE)
        if (file.exists()) {
            val saved = file.readText().trim()
            if (saved.length >= MIN_LENGTH) return saved
        }
        val key = generate()
        write(file, key)
        return key
    }

    /** The saved port, or a new random one if none is saved yet. */
    @Synchronized
    fun port(context: Context): Int {
        val file = File(context.filesDir, PORT_FILE)
        if (file.exists()) {
            file.readText().trim().toIntOrNull()?.let { if (it in PORT_LOW..PORT_HIGH) return it }
        }
        val port = randomPort()
        write(file, port.toString())
        return port
    }

    /** 48 random hex characters. */
    internal fun generate(random: SecureRandom = SecureRandom()): String =
        ByteArray(24).also { random.nextBytes(it) }.joinToString("") { "%02x".format(it) }

    /** A random port in the range Herald uses for its API server. */
    internal fun randomPort(random: SecureRandom = SecureRandom()): Int =
        PORT_LOW + random.nextInt(PORT_HIGH - PORT_LOW + 1)

    private fun write(file: File, text: String) {
        file.parentFile?.mkdirs()
        file.writeText(text)
        // Only this app may read it.
        file.setReadable(false, false)
        file.setReadable(true, true)
        file.setWritable(false, false)
        file.setWritable(true, true)
    }

    const val MIN_LENGTH = 16
}
