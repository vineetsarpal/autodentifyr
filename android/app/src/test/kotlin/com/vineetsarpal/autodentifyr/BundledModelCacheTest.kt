package com.vineetsarpal.autodentifyr

import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.util.Properties
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BundledModelCacheTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val name = "vehicle_damage.tflite"
    private val bytes = ByteArray(16391) { (it % 251).toByte() }
    private val directory get() = File(folder.root, "bundled_models")
    private val model get() = File(directory, name)
    private val metadata get() = File(directory, "$name.properties")
    private val opens = AtomicInteger()

    private fun cache(identity: String = "app:1:100"): BundledModelCache =
        BundledModelCache(directory, identity) {
            opens.incrementAndGet()
            ByteArrayInputStream(bytes)
        }

    @Test
    fun copiesExactBytesOnceAndKeepsTheExistingPath() {
        val cache = cache()
        assertEquals(model.absolutePath, cache.materialize(name))
        assertArrayEquals(bytes, model.readBytes())
        val originalMetadata = metadata.readBytes()
        repeat(5) { assertEquals(model.absolutePath, cache.materialize(name)) }
        assertEquals(1, opens.get())
        assertArrayEquals(originalMetadata, metadata.readBytes())
        assertNoTemporaryFiles()
    }

    @Test
    fun reusesAValidPersistedModelAfterProcessRestart() {
        cache().materialize(name)
        val persistedMetadata = metadata.readBytes()
        assertEquals(model.absolutePath, cache().materialize(name))
        assertEquals(1, opens.get())
        assertArrayEquals(persistedMetadata, metadata.readBytes())
    }

    @Test
    fun invalidatesSameVersionAfterAnotherDevelopmentInstall() {
        cache("app:1:100").materialize(name)
        val updated = "different installed model".toByteArray()
        val next = BundledModelCache(directory, "app:1:101") {
            opens.incrementAndGet()
            ByteArrayInputStream(updated)
        }
        assertEquals(model.absolutePath, next.materialize(name))
        assertArrayEquals(updated, model.readBytes())
        assertEquals(2, opens.get())
        assertEquals(model.absolutePath, next.materialize(name))
        assertEquals(2, opens.get())
    }

    @Test
    fun detectsSameLengthCorruptionOnFirstProcessAccessEvenWithOriginalTimestamp() {
        cache().materialize(name)
        val originalTimestamp = model.lastModified()
        model.writeBytes(ByteArray(bytes.size) { 7 })
        assertTrue(model.setLastModified(originalTimestamp))
        cache().materialize(name)
        assertArrayEquals(bytes, model.readBytes())
        assertEquals(2, opens.get())
    }

    @Test
    fun noticesModelRemovalAndLengthChangesInTheSameProcess() {
        val cache = cache()
        cache.materialize(name)
        assertTrue(model.delete())
        cache.materialize(name)
        model.writeBytes(byteArrayOf(1, 2))
        cache.materialize(name)
        assertEquals(3, opens.get())
        assertArrayEquals(bytes, model.readBytes())
    }

    @Test
    fun missingMalformedOrMismatchedMetadataIsRebuilt() {
        val cache = cache()
        cache.materialize(name)
        assertTrue(metadata.delete())
        cache.materialize(name)
        metadata.writeText("not valid model metadata")
        cache.materialize(name)
        for ((key, value) in listOf(
            "format" to "2",
            "installation" to "other install",
            "model" to "different.tflite",
            "length" to "1",
            "sha256" to "0".repeat(64),
        )) {
            val properties = Properties().apply {
                metadata.inputStream().use { load(it) }
                setProperty(key, value)
            }
            metadata.outputStream().use { properties.store(it, null) }
            // A new process always validates persisted metadata and model bytes.
            cache().materialize(name)
        }
        assertEquals(8, opens.get())
        assertArrayEquals(bytes, model.readBytes())
        assertNoTemporaryFiles()
    }

    @Test
    fun serializesConcurrentRequestsAndCopiesOnlyOnce() {
        val cache = cache()
        val executor = Executors.newFixedThreadPool(8)
        try {
            val calls = List(24) { Callable { cache.materialize(name) } }
            executor.invokeAll(calls).forEach { assertEquals(model.absolutePath, it.get()) }
            assertEquals(1, opens.get())
            assertArrayEquals(bytes, model.readBytes())
        } finally {
            executor.shutdownNow()
            assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS))
        }
        assertNoTemporaryFiles()
    }

    @Test
    fun keepsIndependentModelsInTheSameDirectory() {
        val cache = BundledModelCache(directory, "app:1:100") { requested ->
            opens.incrementAndGet()
            ByteArrayInputStream(requested.toByteArray())
        }
        val otherName = "other.tflite"
        for (requested in listOf(name, otherName, name, otherName)) {
            assertEquals(File(directory, requested).absolutePath, cache.materialize(requested))
        }
        assertEquals(2, opens.get())
        assertArrayEquals(name.toByteArray(), model.readBytes())
        assertArrayEquals(otherName.toByteArray(), File(directory, otherName).readBytes())
    }

    @Test
    fun missingAssetReturnsNullAndCanBeRetried() {
        var present = false
        val cache = BundledModelCache(directory, "app:1:100") {
            if (!present) throw FileNotFoundException(name)
            ByteArrayInputStream(bytes)
        }
        assertNull(cache.materialize(name))
        assertFalse(directory.exists())
        present = true
        assertEquals(model.absolutePath, cache.materialize(name))
    }

    @Test
    fun missingUpdatedAssetDoesNotServeOrDeleteTheOldInstalledModel() {
        cache().materialize(name)
        val next = BundledModelCache(directory, "app:1:101") {
            throw FileNotFoundException(name)
        }
        assertNull(next.materialize(name))
        assertArrayEquals(bytes, model.readBytes())
        assertNoTemporaryFiles()
    }

    @Test
    fun failedCopyPreservesThePreviousModelAndCleansTemporaryFiles() {
        cache().materialize(name)
        val originalMetadata = metadata.readBytes()
        var fail = true
        var closed = false
        val next = BundledModelCache(directory, "app:1:101") {
            if (!fail) ByteArrayInputStream(bytes) else object : InputStream() {
                private var first = true
                override fun read(): Int {
                    if (first) {
                        first = false
                        return 1
                    }
                    throw IOException("read failed")
                }
                override fun close() { closed = true }
            }
        }
        assertThrows(IOException::class.java) { next.materialize(name) }
        assertTrue(closed)
        assertArrayEquals(bytes, model.readBytes())
        assertArrayEquals(originalMetadata, metadata.readBytes())
        assertNoTemporaryFiles()
        fail = false
        assertEquals(model.absolutePath, next.materialize(name))
    }

    @Test
    fun emptyAssetFailsWithoutLeavingPartialModelAndCanBeRetried() {
        var source = byteArrayOf()
        val cache = BundledModelCache(directory, "app:1:100") { ByteArrayInputStream(source) }
        assertThrows(IllegalStateException::class.java) { cache.materialize(name) }
        assertFalse(model.exists())
        assertFalse(metadata.exists())
        assertNoTemporaryFiles()
        source = bytes
        assertEquals(model.absolutePath, cache.materialize(name))
    }

    @Test
    fun failedMetadataReplacementIsRetriedAndCleansTemporaryFiles() {
        assertTrue(metadata.mkdirs())
        val cache = cache()
        assertThrows(IllegalStateException::class.java) { cache.materialize(name) }
        assertNoTemporaryFiles()
        assertTrue(metadata.delete())
        assertEquals(model.absolutePath, cache.materialize(name))
        assertEquals(2, opens.get())
        assertArrayEquals(bytes, model.readBytes())
    }

    @Test
    fun rejectsUnsafeNamesBeforeOpeningAnAsset() {
        for (requested in listOf("../model.tflite", "/model.tflite", "model.zip", "")) {
            assertThrows(IllegalArgumentException::class.java) { cache().materialize(requested) }
        }
        assertEquals(0, opens.get())
        assertFalse(directory.exists())
    }

    private fun assertNoTemporaryFiles() {
        assertFalse(directory.listFiles().orEmpty().any { it.extension == "tmp" })
    }
}
