package net.gmartin.paperlessngx_uploader

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "net.gmartin.paperlessngx_uploader/share"
        private const val EVENT_CHANNEL = "net.gmartin.paperlessngx_uploader/share_stream"
    }

    private var initialSharedFiles: List<String>? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture initial intent (cold start via share)
        initialSharedFiles = resolveShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedFiles" -> {
                        result.success(initialSharedFiles ?: emptyList<String>())
                        initialSharedFiles = null
                    }
                    "reset" -> {
                        initialSharedFiles = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val files = resolveShareIntent(intent)
        if (files.isNotEmpty()) {
            eventSink?.success(files)
        }
    }

    /**
     * Resolves a share intent into a list of local file paths or URL strings.
     * For content:// URIs, copies the file to cache via ContentResolver.
     */
    private fun resolveShareIntent(intent: Intent): List<String> {
        val action = intent.action ?: return emptyList()
        val results = mutableListOf<String>()

        when (action) {
            Intent.ACTION_SEND -> {
                val mimeType = intent.type ?: return emptyList()
                if (mimeType == "text/plain") {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    if (!text.isNullOrBlank()) {
                        val trimmed = text.trim()
                        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
                            results.add(trimmed)
                        }
                    }
                } else {
                    val uri = intent.getParcelableExtraCompat<Uri>(Intent.EXTRA_STREAM)
                    uri?.let {
                        val path = copyUriToCache(it)
                        if (path != null) results.add(path)
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtraCompat<Uri>(Intent.EXTRA_STREAM)
                if (!uris.isNullOrEmpty()) {
                    for (uri in uris) {
                        val path = copyUriToCache(uri)
                        if (path != null) results.add(path)
                    }
                }
            }
        }
        return results
    }

    /**
     * Copies a content:// URI to the app cache directory and returns the file path.
     * Returns the original URI string for file:// URIs.
     */
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            if (uri.scheme == "file") {
                return uri.path
            }

            val resolver: ContentResolver = contentResolver
            val fileName = queryFileName(resolver, uri) ?: "shared_file_${System.currentTimeMillis()}"
            val cacheDir = File(cacheDir, "shared_files")
            if (!cacheDir.exists()) cacheDir.mkdirs()
            val destFile = File(cacheDir, fileName)

            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            destFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Queries the display name for a content URI using ContentResolver.
     */
    private fun queryFileName(resolver: ContentResolver, uri: Uri): String? {
        var name: String? = null
        try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        name = cursor.getString(idx)
                    }
                }
            }
        } catch (_: Exception) {}
        return name
    }

    private inline fun <reified T : Parcelable> Intent.getParcelableExtraCompat(key: String): T? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(key, T::class.java)
        } else {
            @Suppress("DEPRECATION")
            getParcelableExtra(key)
        }

    private inline fun <reified T : Parcelable> Intent.getParcelableArrayListExtraCompat(key: String): ArrayList<T>? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableArrayListExtra(key, T::class.java)
        } else {
            @Suppress("DEPRECATION")
            getParcelableArrayListExtra(key)
        }
}
