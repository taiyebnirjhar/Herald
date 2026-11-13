package com.taiyebnirjhar.herald

import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.gzip.GzipCompressorInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.file.Files
import java.nio.file.Paths
import java.security.MessageDigest

/**
 * Gets the Linux base system (WBS 1.3): downloads the image, checks its
 * SHA-256 against the hash compiled into the app, and extracts it into a
 * folder proot can use as the guest root.
 */
class RootfsInstaller(private val rootDir: File) {

    /** Downloads [url] into [cacheDir], checks it, and extracts it to [rootDir]. */
    fun install(url: String, expectedSha256: String, cacheDir: File, onProgress: (Double) -> Unit): File {
        cacheDir.mkdirs()
        val archive = File(cacheDir, "rootfs.tar.gz")
        val part = File(cacheDir, "rootfs.tar.gz.part")
        part.delete()
        download(url, part, onProgress)
        verifyAndExtract(part, expectedSha256, rootDir)
        part.delete()
        return rootDir
    }

    private fun download(url: String, to: File, onProgress: (Double) -> Unit) {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 15_000
        conn.readTimeout = 60_000
        try {
            if (conn.responseCode != 200) throw IOException("The Linux image download failed (answered ${conn.responseCode})")
            val total = conn.contentLengthLong
            var got = 0L
            conn.inputStream.use { input ->
                FileOutputStream(to).use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        got += n
                        if (total > 0) onProgress(got.toDouble() / total)
                    }
                }
            }
            if (total > 0 && got != total) throw IOException("The Linux image download was incomplete")
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        /**
         * Checks [archive] against [expectedSha256], then extracts it into
         * [dest], replacing what was there. A file that fails the check is
         * deleted and nothing is extracted.
         */
        fun verifyAndExtract(archive: File, expectedSha256: String, dest: File) {
            val actual = sha256Of(archive)
            if (!actual.equals(expectedSha256, ignoreCase = true)) {
                archive.delete()
                throw IOException("The Linux image didn't pass the safety check, so it was not installed")
            }
            val staging = File(dest.parentFile, dest.name + ".new")
            staging.deleteRecursively()
            extract(archive, staging)
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

        /** Extracts a .tar.gz into [dest] with guest-root path rules (see [guestPath]). */
        fun extract(archive: File, dest: File) {
            dest.mkdirs()
            TarArchiveInputStream(
                GzipCompressorInputStream(BufferedInputStream(FileInputStream(archive))),
            ).use { tar ->
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

        /**
         * The host file for guest path [name] under [root], resolved the way
         * proot does: an absolute symlink points into the guest root, not the
         * phone. Names that climb above the root are refused. The last part
         * is followed only when [followLast] is true (not when it's being created).
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
}
