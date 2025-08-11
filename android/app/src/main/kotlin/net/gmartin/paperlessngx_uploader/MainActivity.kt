package net.gmartin.paperlessngx_uploader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "installer_source"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallerSource" -> {
                    // Get the installer package name (e.g., "com.android.vending" for Play Store)
                    val installerPackageName = packageManager.getInstallerPackageName(packageName)
                    result.success(installerPackageName)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
