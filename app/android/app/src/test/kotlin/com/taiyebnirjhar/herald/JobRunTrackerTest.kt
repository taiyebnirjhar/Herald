package com.taiyebnirjhar.herald

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JobRunTrackerTest {

    /** A tiny stand-in for the saved state, so the tests can run several polls in a row. */
    private class FakeStore {
        val values = mutableMapOf<String, String>()
        fun get(jobId: String): String? = values[jobId]

        /** One poll: decide, save, then return what would be announced. */
        fun poll(vararg jobs: JobRunSnapshot): List<FinishedRun> {
            val decision = JobRunTracker.decide(jobs.toList()) { get(it) }
            values.putAll(decision.writes)
            return decision.notices
        }
    }

    private fun job(id: String, exec: String?, status: String?, name: String = "Morning news") =
        JobRunSnapshot(jobId = id, name = name, executionId = exec, status = status)

    @Test
    fun aFinishedRunSeenFirstIsAcceptedSilently() {
        val store = FakeStore()
        assertTrue(store.poll(job("j1", "e1", "completed")).isEmpty())
        assertEquals("e1", store.get("j1"))
    }

    @Test
    fun aRunStillGoingWhenFirstSeenIsAnnouncedOnceItFinishes() {
        val store = FakeStore()
        assertTrue(store.poll(job("j1", "e1", "running")).isEmpty())
        assertEquals("", store.get("j1"))
        assertTrue(store.poll(job("j1", "e1", "running")).isEmpty())
        val notices = store.poll(job("j1", "e1", "completed"))
        assertEquals(1, notices.size)
        assertEquals("e1", notices[0].executionId)
        assertEquals("Morning news finished.", notices[0].body)
    }

    @Test
    fun aRunIsAnnouncedOnlyOnce() {
        val store = FakeStore()
        store.poll(job("j1", "e1", "running"))
        assertEquals(1, store.poll(job("j1", "e1", "completed")).size)
        assertTrue(store.poll(job("j1", "e1", "completed")).isEmpty())
        assertTrue(store.poll(job("j1", "e1", "completed")).isEmpty())
    }

    @Test
    fun aNewRunAfterAnAnnouncedOneIsAnnouncedToo() {
        val store = FakeStore()
        store.poll(job("j1", "e1", "completed"))
        store.poll(job("j1", "e2", "running"))
        assertEquals(1, store.poll(job("j1", "e2", "completed")).size)
        assertTrue(store.poll(job("j1", "e2", "completed")).isEmpty())
    }

    @Test
    fun aRunThatStartsAndEndsBetweenTwoPollsIsAnnounced() {
        val store = FakeStore()
        store.poll(job("j1", "e1", "completed"))
        val notices = store.poll(job("j1", "e2", "failed"))
        assertEquals(1, notices.size)
        assertEquals("failed", notices[0].status)
        assertEquals("Job failed", notices[0].title)
    }

    @Test
    fun aJobThatHasNeverRunIsAnnouncedWhenItsFirstRunEnds() {
        val store = FakeStore()
        assertTrue(store.poll(job("j1", null, null)).isEmpty())
        assertEquals("", store.get("j1"))
        val notices = store.poll(job("j1", "e1", "completed"))
        assertEquals(1, notices.size)
    }

    @Test
    fun unknownEndingIsAnnouncedWithPlainWords() {
        val store = FakeStore()
        store.poll(job("j1", "e1", "running"))
        val notice = store.poll(job("j1", "e1", "unknown")).single()
        assertEquals("Job ended unclearly", notice.title)
        assertEquals("Morning news stopped before it could report a result.", notice.body)
    }

    @Test
    fun aRunStillInProgressIsNotAnnounced() {
        val store = FakeStore()
        store.poll(job("j1", "e1", "completed"))
        assertTrue(store.poll(job("j1", "e2", "claimed")).isEmpty())
        assertTrue(store.poll(job("j1", "e2", "running")).isEmpty())
        assertEquals("e1", store.get("j1"))
    }

    @Test
    fun jobsAreTrackedSeparately() {
        val store = FakeStore()
        store.poll(job("a", "x1", "completed"), job("b", "y1", "completed"))
        // a has a new run; b's run is the one already known.
        val notices = store.poll(job("a", "x2", "completed"), job("b", "y1", "completed"))
        assertEquals(listOf("a"), notices.map { it.jobId })
    }

    @Test
    fun emptyJobIdsAreIgnored() {
        val decision = JobRunTracker.decide(listOf(job("", "e1", "completed"))) { null }
        assertTrue(decision.notices.isEmpty())
        assertTrue(decision.writes.isEmpty())
    }

    @Test
    fun isFinishedOnlyForFinalStatuses() {
        assertTrue(JobRunTracker.isFinished("completed"))
        assertTrue(JobRunTracker.isFinished("failed"))
        assertTrue(JobRunTracker.isFinished("unknown"))
        assertFalse(JobRunTracker.isFinished("running"))
        assertFalse(JobRunTracker.isFinished("claimed"))
        assertFalse(JobRunTracker.isFinished(null))
    }

    @Test
    fun displayNameKeepsAUserGivenName() {
        assertEquals("Morning news", JobRunTracker.displayName("Morning news", "Summarise the news for me"))
    }

    @Test
    fun displayNameHidesThePromptWhenHermesUsedItAsTheName() {
        val prompt = "Summarise the top ten world news stories and send them to me"
        assertEquals(JobRunTracker.FALLBACK_NAME, JobRunTracker.displayName(prompt.take(50), prompt))
    }

    @Test
    fun displayNameFallsBackWhenEmpty() {
        assertEquals(JobRunTracker.FALLBACK_NAME, JobRunTracker.displayName("   ", "Some prompt"))
    }

    @Test
    fun displayNameCollapsesSpacesAndShortensLongNames() {
        assertEquals("a b", JobRunTracker.displayName("  a \n  b ", ""))
        val long = "x".repeat(100)
        val shown = JobRunTracker.displayName(long, "")
        assertEquals(60, shown.length)
        assertTrue(shown.endsWith("..."))
    }

    @Test
    fun noticeTextNeverContainsThePrompt() {
        val notice = FinishedRun("j1", "Morning news", "e1", "failed")
        assertFalse(notice.body.contains("prompt", ignoreCase = true))
        assertEquals("Morning news did not finish. Open Herald to see why.", notice.body)
    }
}
