package net.gmartin.paperlessngx_uploader

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "net.gmartin.paperlessngx_uploader/installSource"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallSource" -> {
                    try {
                        val installSource = getInstallSource()
                        result.success(installSource)
                    } catch (e: Exception) {
                        result.error("SOURCE_ERROR", "Failed to get install source", e.message)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstallSource(): String {
        return try {
            val packageManager = packageManager
            val packageName = packageName
            
            val installSource = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                // Android 11+ (API 30+)
                val installSourceInfo = packageManager.getInstallSourceInfo(packageName)
                installSourceInfo.installingPackageName
            } else {
                // Below Android 11
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(packageName)
            }
            
            when (installSource) {
                "com.android.vending" -> "play_store"
                "org.fdroid.fdroid" -> "f_droid"
                "com.google.android.packageinstaller" -> "apk"
                else -> "apk"
            }
        } catch (e: PackageManager.NameNotFoundException) {
            "apk"
        } catch (e: Exception) {
            "apk"
        }
    }
}
