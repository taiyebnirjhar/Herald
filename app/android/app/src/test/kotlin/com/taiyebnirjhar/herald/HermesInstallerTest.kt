package com.taiyebnirjhar.herald

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HermesInstallerTest {
    @Test
    fun theInstallerRunsAtThePinnedCommitNonInteractively() {
        val command = HermesInstaller.guestCommand()
        assertTrue(command.contains("--non-interactive"))
        val at = command.indexOf("--commit")
        assertEquals(HermesInstaller.PIN_COMMIT, command[at + 1])
        assertEquals(40, HermesInstaller.PIN_COMMIT.length)
    }

    @Test
    fun theInstallerRunsWithACleanEnvironment() {
        val command = HermesInstaller.guestCommand()
        assertEquals("/usr/bin/env", command[0])
        assertEquals("-i", command[1])
        assertTrue(command.contains("/root/hermes-install.sh"))
    }

    @Test
    fun theDownloadIsTheCheckedInPin() {
        assertTrue(HermesInstaller.PINNED_INSTALLER.endsWith("/${HermesInstaller.PIN_COMMIT}/scripts/install.sh"))
    }

    @Test
    fun theBaseImageGetsTheToolsTheInstallerNeeds() {
        val command = HermesInstaller.aptCommand().joinToString(" ")
        assertTrue(command.contains("apt-get install"))
        assertTrue(command.contains("curl"))
        assertTrue(command.contains("git"))
    }
}
