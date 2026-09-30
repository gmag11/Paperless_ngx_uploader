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
    private val initialIntent: InitialIntentHandler by lazy { InitialIntentHandler(shareResolver) }

    // Payloads produced before Dart attaches its event listener (e.g. a warm
    // start received while Flutter is still starting) are buffered here and
    // flushed in onListen so they are not lost.
    private val pendingEvents = mutableListOf<Map<String, List<String>>>()

    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Drop copies left by previous deliveries so the share cache stays bounded.
        shareResolver.pruneStaleCache()
        // Capture the launch intent (cold start via share or "open with").
        // `capture` returns true when the activity intent must be neutralized so
        // that an activity/process recreation does not deliver it again.
        if (initialIntent.capture(intent, savedInstanceState)) {
            setIntent(Intent(Intent.ACTION_MAIN))
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        initialIntent.saveState(outState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedFiles" -> {
                        result.success(payload(initialIntent.consume()))
                    }
                    "reset" -> {
                        initialIntent.reset()
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
                    flushPendingEvents()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val resolution = shareResolver.resolve(intent)
        if (resolution.hasContent()) {
            deliver(payload(resolution))
            // Clear intent so recreation doesn't re-deliver it
            setIntent(Intent(Intent.ACTION_MAIN))
        }
    }

    /**
     * Sends a payload to Dart, buffering it when the event listener has not been
     * attached yet so a warm-start file is not dropped.
     */
    private fun deliver(payload: Map<String, List<String>>) {
        val sink = eventSink
        if (sink == null) {
            pendingEvents.add(payload)
        } else {
            sink.success(payload)
        }
    }

    private fun flushPendingEvents() {
        val sink = eventSink ?: return
        for (payload in pendingEvents) {
            sink.success(payload)
        }
        pendingEvents.clear()
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
}
