package com.vineetsarpal.autodentifyr

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.InputStream
import java.security.DigestOutputStream
import java.security.MessageDigest
import java.util.Properties

/** Keeps an exact copy of an installed package's asset for LiteRT's file loader. */
internal class BundledModelCache(
    private val directory: File,
    private val installedPackageIdentity: String,
    private val openAsset: (String) -> InputStream,
) {
    private data class FileStamp(val length: Long, val modified: Long) {
        companion object {
            fun of(file: File): FileStamp? =
                if (file.isFile) FileStamp(file.length(), file.lastModified()) else null
        }
    }

    private data class ValidatedModel(val model: FileStamp, val metadata: FileStamp)

    private val validatedModels = mutableMapOf<String, ValidatedModel>()

    // Serialize validation and replacement even if another background queue calls us.
    @Synchronized
    fun materialize(name: String): String? {
        require(name.matches(Regex("[A-Za-z0-9_-]+\\.tflite"))) {
            "Expected a TFLite asset filename"
        }
        val destination = File(directory, name)
        val metadata = File(directory, "$name.properties")
        val modelStamp = FileStamp.of(destination)
        val metadataStamp = FileStamp.of(metadata)
        val validated = validatedModels[name]
        if (validated != null && validated.model == modelStamp &&
            validated.metadata == metadataStamp
        ) {
            return destination.absolutePath
        }
        validatedModels.remove(name)
        if (isCurrent(destination, metadata)) {
            remember(name, destination, metadata)
            return destination.absolutePath
        }

        val source = try {
            openAsset(name)
        } catch (_: FileNotFoundException) {
            return null
        }
        source.use { input ->
            check(directory.isDirectory || directory.mkdirs()) { "Cannot create model directory" }
            val temporary = File.createTempFile("model-", ".tmp", directory)
            var temporaryMetadata: File? = null
            try {
                val digest = MessageDigest.getInstance("SHA-256")
                FileOutputStream(temporary).use { output ->
                    val hashedOutput = DigestOutputStream(output, digest)
                    input.copyTo(hashedOutput)
                    hashedOutput.flush()
                    output.fd.sync()
                }
                check(temporary.length() > 0) { "Bundled model is empty" }
                val properties = Properties().apply {
                    setProperty("format", "1")
                    setProperty("installation", installedPackageIdentity)
                    setProperty("model", name)
                    setProperty("length", temporary.length().toString())
                    setProperty("sha256", hex(digest.digest()))
                }
                temporaryMetadata = File.createTempFile("model-metadata-", ".tmp", directory)
                FileOutputStream(temporaryMetadata).use { output ->
                    properties.store(output, null)
                    output.fd.sync()
                }
                // Both files live on the same filesystem. A crash between replacements
                // leaves metadata that fails validation and is rebuilt on the next call.
                check(temporary.renameTo(destination)) { "Cannot replace bundled model" }
                check(temporaryMetadata.renameTo(metadata)) { "Cannot replace model metadata" }
                remember(name, destination, metadata)
                return destination.absolutePath
            } finally {
                temporary.delete()
                temporaryMetadata?.delete()
            }
        }
    }

    private fun isCurrent(destination: File, metadata: File): Boolean {
        if (!destination.isFile || !metadata.isFile) return false
        return try {
            val properties = Properties().apply {
                metadata.inputStream().use { load(it) }
            }
            val length = properties.getProperty("length")?.toLongOrNull()
            val checksum = properties.getProperty("sha256")
            if (properties.getProperty("format") != "1" ||
                properties.getProperty("installation") != installedPackageIdentity ||
                properties.getProperty("model") != destination.name ||
                length == null || length <= 0 || destination.length() != length ||
                checksum == null || !checksum.matches(Regex("[a-f0-9]{64}"))
            ) {
                false
            } else {
                val digest = MessageDigest.getInstance("SHA-256")
                destination.inputStream().use { input ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        digest.update(buffer, 0, read)
                    }
                }
                hex(digest.digest()) == checksum
            }
        } catch (_: Exception) {
            // Unreadable or malformed metadata/model is a cache miss, not a success.
            false
        }
    }

    private fun remember(name: String, destination: File, metadata: File) {
        validatedModels[name] = ValidatedModel(
            checkNotNull(FileStamp.of(destination)),
            checkNotNull(FileStamp.of(metadata)),
        )
    }

    private fun hex(bytes: ByteArray): String = bytes.joinToString("") {
        (it.toInt() and 0xff).toString(16).padStart(2, '0')
    }
}
