package com.taiyebnirjhar.herald

import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveOutputStream
import org.apache.commons.compress.compressors.gzip.GzipCompressorOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.nio.file.Files
import java.nio.file.Paths
import java.security.MessageDigest

class RootfsInstallerTest {
    @get:Rule
    val temp = TemporaryFolder()

    /** Writes a .tar.gz with the given entries: name -> content (null = directory), symlinks by name -> target. */
    private fun makeArchive(
        files: Map<String, ByteArray?> = emptyMap(),
        links: Map<String, String> = emptyMap(),
        exec: Set<String> = emptySet(),
    ): File {
        val archive = temp.newFile("image-${System.nanoTime()}.tar.gz")
        TarArchiveOutputStream(GzipCompressorOutputStream(archive.outputStream())).use { tar ->
            for ((name, data) in files) {
                if (data == null) {
                    tar.putArchiveEntry(TarArchiveEntry("$name/").apply { }) 
                } else {
                    val entry = TarArchiveEntry(name).apply {
                        size = data.size.toLong()
                        mode = if (name in exec) 0x1ed else 0x1a4 // 0755 or 0644
                    }
                    tar.putArchiveEntry(entry)
                    tar.write(data)
                }
                tar.closeArchiveEntry()
            }
            for ((name, target) in links) {
                tar.putArchiveEntry(TarArchiveEntry(name, TarArchiveEntry.LF_SYMLINK).apply { linkName = target })
                tar.closeArchiveEntry()
            }
        }
        return archive
    }

    private fun sha(file: File): String = MessageDigest.getInstance("SHA-256")
        .digest(file.readBytes()).joinToString("") { "%02x".format(it) }

    @Test
    fun filesDirectoriesAndExecutableBitsAreExtracted() {
        val archive = makeArchive(
            files = mapOf(
                "usr" to null,
                "usr/bin/" to null,
                "usr/bin/uname" to "elf".toByteArray(),
                "etc/hostname" to "herald\n".toByteArray(),
            ),
            exec = setOf("usr/bin/uname"),
        )
        val dest = File(temp.root, "root")
        RootfsInstaller.extract(archive, dest)

        assertArrayEquals("elf".toByteArray(), File(dest, "usr/bin/uname").readBytes())
        assertTrue(File(dest, "usr/bin/uname").canExecute())
        assertFalse(File(dest, "etc/hostname").canExecute())
        assertEquals("herald\n", File(dest, "etc/hostname").readText())
    }

    @Test
    fun absoluteSymlinksPointInsideTheGuestRoot() {
        // Like Debian's /lib -> /usr/lib: after extraction the link itself is kept as written.
        val archive = makeArchive(
            files = mapOf("usr/lib/" to null, "usr/lib/libc.so" to "lib".toByteArray()),
            links = mapOf("lib" to "/usr/lib"),
        )
        val dest = File(temp.root, "root")
        RootfsInstaller.extract(archive, dest)

        assertTrue(Files.isSymbolicLink(File(dest, "lib").toPath()))
        assertEquals("/usr/lib", Files.readSymbolicLink(File(dest, "lib").toPath()).toString())
        // A path through the absolute link resolves to the guest file, not the phone's /usr.
        assertEquals(
            File(dest, "usr/lib/libc.so").canonicalPath,
            RootfsInstaller.guestPath(dest, "lib/libc.so", followLast = true).canonicalPath,
        )
    }

    @Test
    fun aPathThatClimbsAboveTheRootIsRefused() {
        val archive = makeArchive(files = mapOf("../escape.txt" to "x".toByteArray()))
        val dest = File(temp.root, "root")
        assertThrows(java.io.IOException::class.java) { RootfsInstaller.extract(archive, dest) }
        assertFalse(File(temp.root, "escape.txt").exists())
    }

    @Test
    fun guestPathRefusesEscapesAndTooManyLinks() {
        val dest = File(temp.root, "root").apply { mkdirs() }
        assertThrows(java.io.IOException::class.java) {
            RootfsInstaller.guestPath(dest, "../x", followLast = false)
        }
        Files.createSymbolicLink(File(dest, "loop").toPath(), Paths.get("loop"))
        assertThrows(java.io.IOException::class.java) {
            RootfsInstaller.guestPath(dest, "loop/x", followLast = true)
        }
    }

    @Test
    fun aLastSymlinkIsReplacedNotFollowed() {
        val archive = makeArchive(
            files = mapOf("data/" to null, "data/file" to "new".toByteArray()),
            links = mapOf("link" to "/data/file"),
        )
        val dest = File(temp.root, "root")
        RootfsInstaller.extract(archive, dest)
        // Extracting a regular file over an existing symlink replaces the link.
        val second = makeArchive(files = mapOf("link" to "plain".toByteArray()))
        RootfsInstaller.extract(second, dest)
        assertFalse(Files.isSymbolicLink(File(dest, "link").toPath()))
        assertEquals("plain", File(dest, "link").readText())
    }

    @Test
    fun aGoodChecksumExtractsAndABadOneDeletesTheFile() {
        val archive = makeArchive(files = mapOf("etc/os-release" to "Debian".toByteArray()))
        val good = sha(archive)
        val dest = File(temp.root, "root")
        RootfsInstaller.verifyAndExtract(archive, good, dest)
        assertEquals("Debian", File(dest, "etc/os-release").readText())

        val tampered = makeArchive(files = mapOf("etc/os-release" to "evil".toByteArray()))
        assertThrows(java.io.IOException::class.java) {
            RootfsInstaller.verifyAndExtract(tampered, "0".repeat(64), File(temp.root, "other"))
        }
        assertFalse(tampered.exists())
        assertFalse(File(temp.root, "other").exists())
    }
}
