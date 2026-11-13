package com.taiyebnirjhar.herald

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test

class HermesSupervisorTest {
    @Test
    fun theRestartWaitDoublesThenGivesUpAfterFiveTries() {
        val b = RestartBackoff()
        val waits = List(5) { b.next() }
        assertEquals(listOf(2_000L, 4_000L, 8_000L, 16_000L, 32_000L), waits)
        assertTrue(b.giveUp)
        assertThrows(IllegalStateException::class.java) { b.next() }
    }

    @Test
    fun theWaitNeverGoesPastOneMinute() {
        val b = RestartBackoff(maxAttempts = 10)
        var last = 0L
        repeat(10) { last = b.next() }
        assertEquals(60_000L, last)
    }

    @Test
    fun resetStartsTheCountAgain() {
        val b = RestartBackoff()
        b.next()
        b.reset()
        assertFalse(b.giveUp)
        assertEquals(2_000L, b.next())
    }

    @Test
    fun hermesListensOnLoopbackOnlyAndNeverOnAllInterfaces() {
        val command = HermesSupervisor.dashboardCommand().joinToString(" ")
        assertTrue(command.contains("--host 127.0.0.1"))
        assertTrue(command.contains("--port 9119"))
        assertFalse(command.contains("0.0.0.0"))
        assertTrue(command.endsWith("--no-open"))
    }

    @Test
    fun theDashboardRunsWithACleanEnvironment() {
        val command = HermesSupervisor.dashboardCommand()
        assertEquals("/usr/bin/env", command[0])
        assertEquals("-i", command[1])
        assertTrue(command.contains("/usr/local/bin/hermes"))
    }

    @Test
    fun theGatewayListensOnLoopbackOnlyAndNeedsTheKey() {
        val command = HermesSupervisor.gatewayCommand("k".repeat(48), 31337)
        assertTrue(command.contains("API_SERVER_HOST=127.0.0.1"))
        assertTrue(command.contains("API_SERVER_PORT=31337"))
        assertTrue(command.contains("API_SERVER_KEY=" + "k".repeat(48)))
        assertFalse(command.any { it.contains("0.0.0.0") })
        assertTrue(command.takeLast(3) == listOf("/usr/local/bin/hermes", "gateway", "run"))
    }

    @Test
    fun theGatewayRunsWithACleanEnvironment() {
        val command = HermesSupervisor.gatewayCommand("k".repeat(48), 31337)
        assertEquals("/usr/bin/env", command[0])
        assertEquals("-i", command[1])
    }

    @Test
    fun withAnInstalledWebUiTheDashboardIsToldWhereItIs() {
        val command = HermesSupervisor.dashboardCommand(HermesSupervisor.WEB_DIST_IN_GUEST)
        assertTrue(command.contains("HERMES_WEB_DIST=${HermesSupervisor.WEB_DIST_IN_GUEST}"))
        // The rest of the command is unchanged: still loopback, still a clean environment.
        assertTrue(command.contains("--host"))
        assertEquals("/usr/bin/env", command[0])
    }

    @Test
    fun withoutAnInstalledWebUiTheVariableIsNotSet() {
        val command = HermesSupervisor.dashboardCommand(null)
        assertFalse(command.any { it.startsWith("HERMES_WEB_DIST") })
    }
}
