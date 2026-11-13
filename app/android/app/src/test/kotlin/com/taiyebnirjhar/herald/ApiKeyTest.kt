package com.taiyebnirjhar.herald

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.SecureRandom

class ApiKeyTest {

    @Test
    fun aGeneratedKeyIsLongEnoughAndHexOnly() {
        val key = ApiKey.generate(SecureRandom())
        assertEquals(48, key.length)
        assertTrue(key.all { it in '0'..'9' || it in 'a'..'f' })
        assertTrue(key.length >= ApiKey.MIN_LENGTH)
    }

    @Test
    fun twoGeneratedKeysAreDifferent() {
        assertNotEquals(ApiKey.generate(SecureRandom()), ApiKey.generate(SecureRandom()))
    }

    @Test
    fun aRandomPortIsInTheHeraldRange() {
        val random = SecureRandom()
        repeat(200) {
            val port = ApiKey.randomPort(random)
            assertTrue(port in 20_000..59_999)
        }
    }
}
