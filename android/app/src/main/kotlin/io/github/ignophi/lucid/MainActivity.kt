package io.github.ignophi.lucid

import android.annotation.TargetApi
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Lucid's own Android code, called from lib/android_system.dart.
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lucid/system")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startSession" -> {
                            val intent = Intent(this, SessionService::class.java)
                                .putExtra(SessionService.EXTRA_TITLE, call.argument<String>("title"))
                                .putExtra(SessionService.EXTRA_TEXT, call.argument<String>("text"))
                                .putExtra(
                                    SessionService.EXTRA_ENDS_AT,
                                    call.argument<Number>("endsAt")?.toLong() ?: 0L
                                )
                                .putExtra(
                                    SessionService.EXTRA_MICROPHONE,
                                    call.argument<Boolean>("microphone") ?: false
                                )
                            if (Build.VERSION.SDK_INT >= 26) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(null)
                        }
                        "stopSession" -> {
                            stopService(Intent(this, SessionService::class.java))
                            result.success(null)
                        }
                        "isScreenOn" -> {
                            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(power.isInteractive)
                        }
                        "saveToDownloads" -> {
                            val folder = call.argument<String>("folder") ?: "Lucid"
                            val name = call.argument<String>("name") ?: "lucid.csv"
                            val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                            result.success(saveToDownloads(folder, name, bytes))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("lucid", e.message, null)
                }
            }
    }

    /// Saves a file to Download/<folder>/<name>, replacing the one Lucid saved
    /// there before. Returns where it went. Needs no storage permission.
    private fun saveToDownloads(folder: String, name: String, bytes: ByteArray): String? {
        if (Build.VERSION.SDK_INT < 29) {
            // Older Android: the app's own folder on the phone storage
            val dir = File(getExternalFilesDir(null), folder)
            dir.mkdirs()
            val file = File(dir, name)
            file.writeBytes(bytes)
            return file.absolutePath
        }
        return saveToMediaStore(folder, name, bytes)
    }

    @TargetApi(29)
    private fun saveToMediaStore(folder: String, name: String, bytes: ByteArray): String? {
        val resolver = contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val relativePath = Environment.DIRECTORY_DOWNLOADS + "/" + folder + "/"
        var uri: Uri? = null
        resolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?",
            arrayOf(relativePath, name),
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                uri = ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
        }
        if (uri == null) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            }
            uri = resolver.insert(collection, values) ?: return null
        }
        resolver.openOutputStream(uri!!, "wt")?.use { it.write(bytes) } ?: return null
        return relativePath + name
    }
}
