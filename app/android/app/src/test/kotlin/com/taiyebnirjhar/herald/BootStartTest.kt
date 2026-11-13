package com.taiyebnirjhar.herald

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BootStartTest {

    @Test
    fun `starts when the switch is on and Hermes is installed`() {
        assertTrue(BootStart.shouldStart(setting = true, hermesInstalled = true))
    }

    @Test
    fun `does not start when the player turned the switch off`() {
        assertFalse(BootStart.shouldStart(setting = false, hermesInstalled = true))
    }

    @Test
    fun `missing setting counts as on, same as Settings`() {
        assertTrue(BootStart.shouldStart(setting = null, hermesInstalled = true))
    }

    @Test
    fun `does not start when Hermes is not installed yet`() {
        assertFalse(BootStart.shouldStart(setting = true, hermesInstalled = false))
        assertFalse(BootStart.shouldStart(setting = null, hermesInstalled = false))
    }
}
