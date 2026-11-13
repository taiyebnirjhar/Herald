package com.taiyebnirjhar.herald

/**
 * Whether an earlier download can be reused, or must be downloaded again.
 * A finished download is reused only while its file is still on the phone.
 * A download that failed is never reused.
 */
internal object DownloadReuse {
    fun shouldReuse(state: String, fileExists: Boolean): Boolean = when (state) {
        "running", "waiting" -> true
        "done" -> fileExists
        else -> false
    }
}
