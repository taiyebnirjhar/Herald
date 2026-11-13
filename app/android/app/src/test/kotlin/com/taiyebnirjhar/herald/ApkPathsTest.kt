package com.taiyebnirjhar.herald

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class ApkPathsTest {
    @get:Rule
    val temp = TemporaryFolder()

    private lateinit var cache: File
    private lateinit var updates: File

    private fun setUp() {
        cache = temp.newFolder("cache")
        updates = File(cache, "updates").apply { mkdirs() }
    }

    @Test
    fun anApkInTheUpdatesFolderIsInstallable() {
        setUp()
        val apk = File(updates, "herald-0.1.3.apk").apply { writeText("x") }
        assertTrue(ApkPaths.isInstallable(apk, cache))
    }

    @Test
    fun anApkOutsideTheUpdatesFolderIsRefused() {
        setUp()
        val apk = File(cache, "herald-0.1.3.apk").apply { writeText("x") }
        assertFalse(ApkPaths.isInstallable(apk, cache))
    }

    @Test
    fun aFileThatIsNotAnApkIsRefused() {
        setUp()
        val file = File(updates, "herald-0.1.3.zip").apply { writeText("x") }
        assertFalse(ApkPaths.isInstallable(file, cache))
    }

    @Test
    fun aMissingFileIsRefused() {
        setUp()
        assertFalse(ApkPaths.isInstallable(File(updates, "gone.apk"), cache))
    }

    @Test
    fun aFolderNamedLikeAnApkIsRefused() {
        setUp()
        val folder = File(updates, "trick.apk").apply { mkdirs() }
        assertFalse(ApkPaths.isInstallable(folder, cache))
    }

    @Test
    fun dotDotEscapesAreRefused() {
        setUp()
        val outside = File(cache, "secret.apk").apply { writeText("x") }
        // Goes out of updates/ and back in with "..": the canonical path is outside.
        val sneaky = File(updates, "../secret.apk")
        assertFalse(ApkPaths.isInstallable(sneaky, cache))
        assertTrue(outside.exists())
    }
}
