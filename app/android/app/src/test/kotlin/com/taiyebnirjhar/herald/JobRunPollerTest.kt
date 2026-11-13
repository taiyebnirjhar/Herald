package com.taiyebnirjhar.herald

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class JobRunPollerTest {

    @Test
    fun parsesJobsFromHermesListShape() {
        val body = """
            {"jobs": [
              {"id": "job-1", "name": "Morning news", "prompt": "Summarise the news",
               "latest_execution": {"id": "exec-1", "status": "completed", "pid": 42}},
              {"id": "job-2", "name": "Weekly report", "prompt": "Write it",
               "latest_execution": null},
              {"id": "", "name": "No id", "prompt": "", "latest_execution": null}
            ]}
        """.trimIndent()
        val jobs = JobRunPoller.parseJobs(body)
        assertEquals(2, jobs.size)
        assertEquals(JobRunSnapshot("job-1", "Morning news", "exec-1", "completed"), jobs[0])
        assertEquals(JobRunSnapshot("job-2", "Weekly report", null, null), jobs[1])
    }

    @Test
    fun theSnapshotNeverKeepsThePrompt() {
        val body = """{"jobs": [{"id": "j", "name": "", "prompt": "secret instructions here",
            "latest_execution": {"id": "e", "status": "running"}}]}"""
        val job = JobRunPoller.parseJobs(body).single()
        assertEquals(JobRunTracker.FALLBACK_NAME, job.name)
        assertFalse(job.name.contains("secret"))
        assertFalse(job.toString().contains("secret"))
    }

    @Test
    fun aMissingJobsListGivesNoJobs() {
        assertTrue(JobRunPoller.parseJobs("{}").isEmpty())
    }

    @Test
    fun anEmptyExecutionIdBecomesNull() {
        val body = """{"jobs": [{"id": "j", "name": "n", "latest_execution": {"id": "", "status": ""}}]}"""
        val job = JobRunPoller.parseJobs(body).single()
        assertNull(job.executionId)
        assertNull(job.status)
    }
}
