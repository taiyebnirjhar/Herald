package com.taiyebnirjhar.herald

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DownloadReuseTest {

    @Test
    fun aDownloadThatIsStillRunningOrWaitingIsReused() {
        assertTrue(DownloadReuse.shouldReuse("running", fileExists = false))
        assertTrue(DownloadReuse.shouldReuse("waiting", fileExists = false))
    }

    @Test
    fun aFinishedDownloadIsReusedOnlyWhileItsFileIsThere() {
        assertTrue(DownloadReuse.shouldReuse("done", fileExists = true))
        assertFalse(DownloadReuse.shouldReuse("done", fileExists = false))
    }

    @Test
    fun aFailedOrUnknownDownloadIsNeverReused() {
        assertFalse(DownloadReuse.shouldReuse("failed", fileExists = true))
        assertFalse(DownloadReuse.shouldReuse("none", fileExists = true))
    }
}
