package com.vineetsarpal.autodentifyr

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File

class MainActivity : FlutterActivity() {
    private var modelAssetsChannel: MethodChannel? = null

    private val bundledModelCache: BundledModelCache by lazy {
        synchronized(MainActivity::class.java) {
            sharedModelCache ?: run {
                val context = applicationContext
                // The legacy overload supports every Android version targeted by Flutter.
                @Suppress("DEPRECATION")
                val info = context.packageManager.getPackageInfo(context.packageName, 0)
                val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    info.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    info.versionCode.toLong()
                }
                BundledModelCache(
                    File(context.filesDir, "bundled_models"),
                    "${context.packageName}:${info.versionName}:$versionCode:${info.lastUpdateTime}",
                    context.assets::open,
                ).also { sharedModelCache = it }
            }
        }
    }

    companion object {
        private var sharedModelCache: BundledModelCache? = null
    }

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
                    result.success(bundledModelCache.materialize(name))
                } catch (e: Exception) {
                    result.error("model_asset_error", e.message, null)
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        modelAssetsChannel?.setMethodCallHandler(null)
        modelAssetsChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
