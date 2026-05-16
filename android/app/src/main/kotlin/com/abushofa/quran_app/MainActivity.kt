package com.abushofa.quran_app

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.abushofa.quran_app/media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            MediaScannerConnection.scanFile(this, arrayOf(path), null) { _, _ -> }
                            result.success(true)
                        } else {
                            result.error("INVALID_ARG", "path is null", null)
                        }
                    }
                    "getManufacturer" -> {
                        result.success(android.os.Build.MANUFACTURER.lowercase())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
