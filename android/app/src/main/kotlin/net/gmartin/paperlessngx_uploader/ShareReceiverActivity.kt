package net.gmartin.paperlessngx_uploader

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ShareReceiverActivity : FlutterActivity() {
    private val CHANNEL = "net.gmartin.paperlessngx_uploader/share"
    private var sharedFilePaths: List<String> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedFile" -> {
                        result.success(sharedFilePaths)
                        sharedFilePaths = emptyList()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type != null) {
                    val uri = intent.getParcelableExtraCompat<Uri>(Intent.EXTRA_STREAM)
                    uri?.let { sharedFilePaths = listOf(uriToString(it)) }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                if (intent.type != null) {
                    val uris = intent.getParcelableArrayListExtraCompat<Uri>(Intent.EXTRA_STREAM)
                    if (!uris.isNullOrEmpty()) {
                        sharedFilePaths = uris.map { uriToString(it) }
                    }
                }
            }
        }
    }

    /**
     * Returns a string representation of the URI suitable for the Flutter layer.
     * For content:// URIs we return the URI string directly; the Dart side uses
     * the uri with a ContentResolver to open an InputStream, which is the modern
     * approach since MediaStore.Images.Media.DATA is deprecated since API 29.
     */
    private fun uriToString(uri: Uri): String = uri.toString()

    // ── Compat helpers ────────────────────────────────────────────────────────

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