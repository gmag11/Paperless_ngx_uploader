package com.example.paperless_ngx_android_uploader

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ShareReceiverActivity : FlutterActivity() {
    private val CHANNEL = "com.example.paperless_ngx_android_uploader/share"
    private var sharedFilePath: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle the share intent
        handleShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedFile" -> {
                        result.success(sharedFilePath)
                        sharedFilePath = null // Clear after reading
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
                    val uri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                    uri?.let {
                        sharedFilePath = getRealPathFromURI(it)
                    }
                }
            }
        }
    }

    private fun getRealPathFromURI(uri: android.net.Uri): String? {
        var path: String? = null
        
        // Handle content:// URIs
        if (uri.scheme == "content") {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val columnIndex = it.getColumnIndex(android.provider.MediaStore.Images.Media.DATA)
                    if (columnIndex != -1) {
                        path = it.getString(columnIndex)
                    }
                }
            }
            
            // Fallback for documents
            if (path == null) {
                path = uri.toString()
            }
        } else if (uri.scheme == "file") {
            path = uri.path
        }
        
        return path
    }
}