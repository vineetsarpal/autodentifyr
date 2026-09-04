package com.vineetsarpal.autodentifyr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.io.FileNotFoundException

class MainActivity : FlutterActivity() {
    private var modelAssetsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        modelAssetsChannel = MethodChannel(
            messenger,
            "autodentifyr/model_assets",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "materializeModel") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                if (name == null || !name.matches(Regex("[A-Za-z0-9_-]+\\.tflite"))) {
                    result.error("invalid_model_name", "Expected a TFLite asset filename", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(materializeModel(name))
                } catch (e: Exception) {
                    result.error("model_asset_error", e.message, null)
                }
            }
        }
    }

    // LiteRT's file loader requires an absolute file, not an Android asset name.
    // Copy off the UI thread, then atomically replace to avoid partial/stale models.
    private fun materializeModel(name: String): String? {
        val source = try {
            assets.open(name)
        } catch (_: FileNotFoundException) {
            return null
        }
        source.use { input ->
            val directory = File(filesDir, "bundled_models")
            check(directory.isDirectory || directory.mkdirs()) { "Cannot create model directory" }
            val destination = File(directory, name)
            val temporary = File.createTempFile("model-", ".tmp", directory)
            try {
                temporary.outputStream().use { output -> input.copyTo(output) }
                check(temporary.length() > 0) { "Bundled model is empty" }
                check(temporary.renameTo(destination)) { "Cannot replace bundled model" }
                return destination.absolutePath
            } finally {
                temporary.delete()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        modelAssetsChannel?.setMethodCallHandler(null)
        modelAssetsChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
