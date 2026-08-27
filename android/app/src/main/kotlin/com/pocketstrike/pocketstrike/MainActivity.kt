package com.pocketstrike.pocketstrike

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.pocketstrike.app/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "PocketStrike_${System.currentTimeMillis()}.jpg"

                    if (bytes == null || bytes.isEmpty()) {
                        result.error("INVALID_DATA", "Image bytes cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val savedUri = saveImageToMediaStore(bytes, fileName)
                        if (savedUri != null) {
                            result.success(savedUri)
                        } else {
                            result.error("SAVE_FAILED", "Failed to save image to MediaStore", null)
                        }
                    } catch (e: Exception) {
                        result.error("EXCEPTION", e.localizedMessage ?: "Unknown error", null)
                    }
                }
                "shareImage" -> {
                    val filePath = call.argument<String>("filePath")
                    val text = call.argument<String>("text") ?: "Created with PocketStrike AI"
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            if (file.exists()) {
                                val uri = androidx.core.content.FileProvider.getUriForFile(
                                    applicationContext,
                                    "${applicationContext.packageName}.fileprovider",
                                    file
                                )
                                val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                                    type = "image/jpeg"
                                    putExtra(android.content.Intent.EXTRA_STREAM, uri)
                                    putExtra(android.content.Intent.EXTRA_TEXT, text)
                                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                val chooser = android.content.Intent.createChooser(intent, "Share AI Image via").apply {
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                applicationContext.startActivity(chooser)
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            }
                        } catch (e: Exception) {
                            result.error("EXCEPTION", e.localizedMessage ?: "Unknown error", null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                "deleteFromMediaStore" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")
                    try {
                        if (filePath != null) {
                            val file = File(filePath)
                            if (file.exists()) {
                                file.delete()
                            }
                        }
                        if (fileName != null) {
                            val resolver = applicationContext.contentResolver
                            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                            } else {
                                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                            }
                            val where = "${MediaStore.Images.Media.DISPLAY_NAME} = ?"
                            val args = arrayOf(fileName)
                            resolver.delete(collection, where, args)
                        }
                        if (filePath != null) {
                            MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(filePath),
                                arrayOf("image/jpeg", "image/png"),
                                null
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("EXCEPTION", e.localizedMessage ?: "Unknown error", null)
                    }
                }
                "scanFilePath" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(filePath),
                            arrayOf("image/jpeg", "image/png"),
                            null
                        )
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveImageToMediaStore(bytes: ByteArray, fileName: String): String? {
        val resolver = applicationContext.contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/PocketStrike")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val imageUri: Uri? = resolver.insert(collection, contentValues)

        if (imageUri != null) {
            resolver.openOutputStream(imageUri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(imageUri, contentValues, null, null)
            }

            return imageUri.toString()
        }

        // Fallback for devices without MediaStore insert access
        val picturesDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "PocketStrike")
        if (!picturesDir.exists()) {
            picturesDir.mkdirs()
        }
        val destFile = File(picturesDir, fileName)
        FileOutputStream(destFile).use { fos ->
            fos.write(bytes)
            fos.flush()
        }
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(destFile.absolutePath),
            arrayOf("image/jpeg"),
            null
        )
        return destFile.absolutePath
    }
}
