package com.abushofa.quran_app

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
                    "saveToDownloads" -> {
                        val srcPath = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName")
                        if (srcPath == null || fileName == null) {
                            result.error("INVALID_ARG", "path or fileName is null", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val srcFile = File(srcPath)
                            if (!srcFile.exists()) {
                                result.error("FILE_NOT_FOUND", "Source file not found: $srcPath", null)
                                return@setMethodCallHandler
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                // Android 10+: use MediaStore Downloads (visible everywhere)
                                val resolver = contentResolver
                                val values = ContentValues().apply {
                                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                                    put(MediaStore.Downloads.MIME_TYPE, "audio/aac")
                                    put(MediaStore.Downloads.RELATIVE_PATH, "Download/AlTayseer")
                                    put(MediaStore.Downloads.IS_PENDING, 1)
                                }
                                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                if (uri != null) {
                                    resolver.openOutputStream(uri)?.use { out ->
                                        srcFile.inputStream().use { it.copyTo(out) }
                                    }
                                    values.clear()
                                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                                    resolver.update(uri, values, null, null)
                                    srcFile.delete()
                                    result.success(uri.toString())
                                } else {
                                    result.error("INSERT_FAILED", "MediaStore insert returned null", null)
                                }
                            } else {
                                // Android 9-: write directly to Downloads
                                val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                                val targetDir = File(downloadsDir, "AlTayseer")
                                targetDir.mkdirs()
                                val targetFile = File(targetDir, fileName)
                                srcFile.copyTo(targetFile, overwrite = true)
                                srcFile.delete()
                                MediaScannerConnection.scanFile(this, arrayOf(targetFile.absolutePath), null) { _, _ -> }
                                result.success(targetFile.absolutePath)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
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
