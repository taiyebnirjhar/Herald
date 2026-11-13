package com.taiyebnirjhar.herald

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProviderSetupTest {

    private val key = "sk-or-v1-0123456789abcdef"

    @Test
    fun aGoodKeyAndModelHaveNoProblem() {
        assertNull(ProviderSetup.problem(Provider.OPENROUTER, key, "openrouter/auto"))
    }

    @Test
    fun aMissingProviderIsAProblem() {
        assertNotNull(ProviderSetup.problem(null, key, "m"))
    }

    @Test
    fun aShortOrSpacedKeyIsAProblemAndTheKeyIsNotEchoed() {
        val short = ProviderSetup.problem(Provider.XAI, "abc", "grok-4")
        val spaced = ProviderSetup.problem(Provider.XAI, "abc def ghi jkl", "grok-4")
        assertNotNull(short)
        assertNotNull(spaced)
        assertFalse(short!!.contains("abc"))
        assertFalse(spaced!!.contains("abc"))
    }

    @Test
    fun aBlankOrSpacedModelIsAProblem() {
        assertNotNull(ProviderSetup.problem(Provider.GEMINI, key, "  "))
        assertNotNull(ProviderSetup.problem(Provider.GEMINI, key, "gemini 2.5"))
    }

    @Test
    fun threeCommandsSaveTheKeyProviderAndModel() {
        val commands = ProviderSetup.commands(Provider.GEMINI, key, "gemini-2.5-flash")
        assertEquals(3, commands.size)
        assertTrue(commands[0].containsAll(listOf("config", "set", "GEMINI_API_KEY", key)))
        assertTrue(commands[1].containsAll(listOf("config", "set", "model.provider", "gemini")))
        assertTrue(commands[2].containsAll(listOf("config", "set", "model.default", "gemini-2.5-flash")))
    }

    @Test
    fun theKeyGoesOnlyIntoTheFirstCommand() {
        val commands = ProviderSetup.commands(Provider.OPENROUTER, key, "openrouter/auto")
        assertTrue(commands.drop(1).none { it.contains(key) })
    }

    @Test
    fun commandsRunWithACleanEnvironmentInsideTheLinuxBase() {
        for (command in ProviderSetup.commands(Provider.XAI, key, "grok-4")) {
            assertEquals("/usr/bin/env", command[0])
            assertEquals("-i", command[1])
            assertTrue(command.contains("/usr/local/bin/hermes"))
        }
    }

    @Test
    fun providerIdsMatchHermes() {
        assertEquals(Provider.OPENROUTER, Provider.byId("openrouter"))
        assertEquals(Provider.GEMINI, Provider.byId("gemini"))
        assertEquals(Provider.XAI, Provider.byId("xai"))
        assertNull(Provider.byId("nope"))
    }
}
