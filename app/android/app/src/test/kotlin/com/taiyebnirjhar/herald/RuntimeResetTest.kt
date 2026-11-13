package com.taiyebnirjhar.herald

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class RuntimeResetTest {
    @get:Rule
    val temp = TemporaryFolder()

    private fun runtimeWithLinux(): File {
        val runtime = temp.newFolder("runtime")
        File(runtime, "${RuntimeReset.RootfsName}/usr/bin").apply { mkdirs() }
        File(runtime, "${RuntimeReset.RootfsName}/usr/bin/uname").writeText("elf")
        return runtime
    }

    @Test
    fun repairRemovesTheLinuxBaseSoItCanBeUnpackedAgain() {
        val runtime = runtimeWithLinux()
        assertTrue(RuntimeReset.repair(runtime))
        assertFalse(File(runtime, RuntimeReset.RootfsName).exists())
    }

    @Test
    fun resetRemovesTheLinuxBaseDownloadsAndLog() {
        val runtime = runtimeWithLinux()
        val downloads = temp.newFolder("downloads").also { File(it, "image.tar.gz").writeText("x") }
        val log = File(temp.root, "hermes-install.log").apply { writeText("log") }

        assertTrue(RuntimeReset.reset(runtime, downloads, log))
        assertFalse(runtime.exists())
        assertFalse(downloads.exists())
        assertFalse(log.exists())
    }

    @Test
    fun resetOfNothingIsFine() {
        val missing = File(temp.root, "missing")
        assertTrue(RuntimeReset.reset(missing, File(temp.root, "nope"), File(temp.root, "nolog")))
    }

    @Test
    fun spaceNeededIsAtLeastTheImageTwice() {
        assertTrue(RuntimeReset.LINUX_NEED_BYTES >= 2L * 52_000_000)
    }
}
