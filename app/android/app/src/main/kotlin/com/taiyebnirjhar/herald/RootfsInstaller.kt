package com.taiyebnirjhar.herald

import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.gzip.GzipCompressorInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FilterInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.nio.file.Files
import java.nio.file.Paths
import java.security.MessageDigest

/**
 * Unpacks the Linux base system (WBS 1.3) into a folder proot can use as the
 * guest root. The image is checked against its SHA-256 before anything is unpacked.
 */
object RootfsInstaller {

    /** Progress: a stage name and its fraction 0.0–1.0. */
    typealias Progress = (String, Double) -> Unit

    /** Checks [archive] against [expectedSha256], then unpacks it into [dest], replacing what was there. */
    fun verifyAndExtract(archive: File, expectedSha256: String, dest: File, progress: Progress = { _, _ -> }) {
        progress("Checking the Linux image", 0.0)
        val actual = sha256Of(archive)
        if (!actual.equals(expectedSha256, ignoreCase = true)) {
            archive.delete()
            throw IOException("The Linux image didn't pass the safety check, so it was not installed")
        }
        val staging = File(dest.parentFile, dest.name + ".new")
        staging.deleteRecursively()
        extract(archive, staging) { f -> progress("Unpacking the Linux image", f) }
        dest.deleteRecursively()
        if (!staging.renameTo(dest)) throw IOException("Couldn't put the Linux image in place")
    }

    fun sha256Of(file: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    /** Unpacks a .tar.gz into [dest] with guest-root path rules (see [guestPath]). */
    fun extract(archive: File, dest: File, onProgress: (Double) -> Unit = {}) {
        dest.mkdirs()
        val total = archive.length().coerceAtLeast(1L)
        var read = 0L
        var last = -1.0
        val counted = object : FilterInputStream(FileInputStream(archive)) {
            override fun read(): Int {
                val b = super.read()
                if (b >= 0) tick(1)
                return b
            }

            override fun read(b: ByteArray, off: Int, len: Int): Int {
                val n = super.read(b, off, len)
                if (n > 0) tick(n)
                return n
            }

            private fun tick(n: Int) {
                read += n
                val f = (read.toDouble() / total).coerceIn(0.0, 1.0)
                if (f - last >= 0.01 || f >= 1.0) {
                    last = f
                    onProgress(f)
                }
            }
        }
        TarArchiveInputStream(GzipCompressorInputStream(BufferedInputStream(counted))).use { tar ->
            var entry = tar.nextTarEntry
            while (entry != null) {
                val target = guestPath(dest, entry.name, followLast = false)
                when {
                    entry.isDirectory -> target.mkdirs()
                    entry.isSymbolicLink -> {
                        target.parentFile?.mkdirs()
                        Files.deleteIfExists(target.toPath())
                        Files.createSymbolicLink(target.toPath(), Paths.get(entry.linkName))
                    }
                    entry.isLink -> {
                        val source = guestPath(dest, entry.linkName, followLast = true)
                        target.parentFile?.mkdirs()
                        Files.deleteIfExists(target.toPath())
                        source.copyTo(target, overwrite = true)
                    }
                    entry.isFile -> {
                        target.parentFile?.mkdirs()
                        Files.deleteIfExists(target.toPath())
                        FileOutputStream(target).use { tar.copyTo(it) }
                        if (entry.mode and 0x49 != 0) target.setExecutable(true, false)
                    }
                    else -> Unit // devices and pipes are not needed
                }
                entry = tar.nextTarEntry
            }
        }
    }

    /** Copies [input] (of [total] bytes, if known) to [to], reporting its fraction. */
    fun copy(input: InputStream, to: File, total: Long, onProgress: (Double) -> Unit) {
        var got = 0L
        var last = -1.0
        FileOutputStream(to).use { out ->
            val buf = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                out.write(buf, 0, n)
                got += n
                if (total > 0) {
                    val f = (got.toDouble() / total).coerceIn(0.0, 1.0)
                    if (f - last >= 0.01) {
                        last = f
                        onProgress(f)
                    }
                }
            }
        }
    }

    /**
     * The host file for guest path [name] under [root], resolved the way
     * proot does: an absolute symlink points into the guest root, not the
     * phone. Names that climb above the root are refused. The last part is
     * followed only when [followLast] is true (not when it's being created).
     */
    fun guestPath(root: File, name: String, followLast: Boolean): File {
        val pending = ArrayDeque(name.split('/').filter { it.isNotEmpty() && it != "." })
        val out = ArrayList<String>()
        var hops = 0
        while (pending.isNotEmpty()) {
            val part = pending.removeFirst()
            if (part == "..") {
                if (out.isEmpty()) throw IOException("Unsafe path in the Linux image: $name")
                out.removeAt(out.size - 1)
                continue
            }
            val host = File(root, (out + part).joinToString("/"))
            val isLast = pending.isEmpty()
            if (!isLast || followLast) {
                if (Files.isSymbolicLink(host.toPath())) {
                    if (++hops > 40) throw IOException("Too many links in the Linux image: $name")
                    val target = Files.readSymbolicLink(host.toPath()).toString()
                    if (target.startsWith("/")) out.clear()
                    val targetParts = target.split('/').filter { it.isNotEmpty() && it != "." }
                    for (i in targetParts.indices.reversed()) pending.addFirst(targetParts[i])
                    continue
                }
            }
            out.add(part)
        }
        return if (out.isEmpty()) root else File(root, out.joinToString("/"))
    }
}
