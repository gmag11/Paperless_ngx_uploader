package net.gmartin.paperlessngx_uploader

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "net.gmartin.paperlessngx_uploader/share"
        private const val EVENT_CHANNEL = "net.gmartin.paperlessngx_uploader/share_stream"
    }

    private val shareResolver: ShareIntentResolver by lazy { ShareIntentResolver(this) }

    private var initialResolution: ShareResolution? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture initial intent (cold start via share or "open with")
        initialResolution = shareResolver.resolve(intent)
        // Clear the stored intent so that if Android recreates this activity
        // (e.g. after killing it due to memory pressure while backgrounded),
        // the share intent is not re-delivered and files are not uploaded again.
        if (hasContent(initialResolution)) {
            setIntent(Intent(Intent.ACTION_MAIN))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedFiles" -> {
                        result.success(payload(initialResolution))
                        initialResolution = null
                    }
                    "reset" -> {
                        initialResolution = null
                        result.success(null)
                    }
                    "moveToBackground" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "finishAndRemoveTask" -> {
                        finishAndRemoveTask()
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
        val resolution = shareResolver.resolve(intent)
        if (hasContent(resolution)) {
            eventSink?.success(payload(resolution))
            // Clear intent so recreation doesn't re-deliver it
            setIntent(Intent(Intent.ACTION_MAIN))
        }
    }

    /**
     * Payload sent to Dart: `{files, errors}`. Only readable paths are in
     * [files]; the display names of the files that could not be read are in
     * [errors], so the UI can show a notice instead of pretending they arrived.
     */
    private fun payload(resolution: ShareResolution?): Map<String, List<String>> {
        if (resolution == null) return mapOf("files" to emptyList<String>(), "errors" to emptyList<String>())
        return mapOf("files" to resolution.files, "errors" to resolution.errors)
    }

    private fun hasContent(resolution: ShareResolution?): Boolean =
        resolution != null && (resolution.files.isNotEmpty() || resolution.errors.isNotEmpty())
}
