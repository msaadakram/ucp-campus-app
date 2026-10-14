package com.example.ucp

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "ucp/downloads"
    private val permRequestCode = 1401
    private var pendingResult: MethodChannel.Result? = null
    private var pendingName: String? = null
    private var pendingMime: String? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name") ?: "download"
                val mime = call.argument<String>("mimeType")
                    ?: "application/octet-stream"
                if (path == null || !File(path).exists()) {
                    result.error("NOT_FOUND", "source file missing", null)
                    return@setMethodCallHandler
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val dest = mediaStoreCopy(path, name, mime)
                        result.success(dest)
                    } else {
                        if (hasLegacyWritePermission()) {
                            val dest = legacyCopy(path, name)
                            result.success(dest)
                        } else {
                            // Stash and ask; reply arrives in
                            // onRequestPermissionsResult.
                            pendingResult = result
                            pendingPath = path
                            pendingName = name
                            pendingMime = mime
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.WRITE_EXTERNAL_STORAGE,
                                ),
                                permRequestCode,
                            )
                        }
                    }
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permRequestCode) return
        val result = pendingResult
        val path = pendingPath
        val name = pendingName
        pendingResult = null
        pendingPath = null
        pendingName = null
        pendingMime = null
        if (result == null || path == null || name == null) return
        try {
            if (grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            ) {
                result.success(legacyCopy(path, name))
            } else {
                result.error("DENIED", "storage permission denied", null)
            }
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, null)
        }
    }

    private fun hasLegacyWritePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED
    }

    /** API 29+: MediaStore insert into Download/UCP — no permission needed. */
    private fun mediaStoreCopy(srcPath: String, name: String, mime: String): String {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, "Download/UCP")
        }
        val resolver = contentResolver
        val uri = resolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values,
        ) ?: throw IllegalStateException("media store insert failed")
        FileInputStream(srcPath).use { input ->
            resolver.openOutputStream(uri)?.use { output ->
                input.copyTo(output)
            } ?: throw IllegalStateException("media store write failed")
        }
        return "Download/UCP/$name"
    }

    /** API <29: direct copy into the public Download folder. */
    private fun legacyCopy(srcPath: String, name: String): String {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS,
            ),
            "UCP",
        )
        if (!dir.exists()) dir.mkdirs()
        val dest = uniqueFile(dir, name)
        FileInputStream(srcPath).use { input ->
            FileOutputStream(dest).use { output ->
                input.copyTo(output)
            }
        }
        return dest.absolutePath
    }

    private fun uniqueFile(dir: File, name: String): File {
        var candidate = File(dir, name)
        if (!candidate.exists()) return candidate
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        for (i in 1..999) {
            candidate = File(dir, "$stem ($i)$ext")
            if (!candidate.exists()) return candidate
        }
        return File(dir, "$stem (${System.currentTimeMillis()})$ext")
    }
}
