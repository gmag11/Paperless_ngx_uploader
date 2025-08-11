import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Service to detect the installer source of the app
/// Used to determine if the app was installed from Play Store, F-Droid, or other sources
class InstallerSourceService {
  static const MethodChannel _channel = MethodChannel('installer_source');

  /// Gets the installer package name that installed this app
  /// Returns: String with package name (e.g., "com.android.vending" for Play Store,
  /// "org.fdroid.fdroid" for F-Droid) or null if not available
  static Future<String?> getInstallerSource() async {
    try {
      final String? installerPackageName = await _channel.invokeMethod('getInstallerSource');
      return installerPackageName;
    } on PlatformException catch (e) {
      // Handle platform exceptions gracefully
      developer.log(
        'Failed to get installer source',
        error: e.message,
        name: 'InstallerSourceService',
      );
      return null;
    }
  }

  /// Checks if the app was installed from Google Play Store
  static Future<bool> isFromPlayStore() async {
    final source = await getInstallerSource();
    return source == 'com.android.vending';
  }

  /// Checks if the app was installed from F-Droid
  static Future<bool> isFromFDroid() async {
    final source = await getInstallerSource();
    return source == 'org.fdroid.fdroid';
  }

  /// Checks if the app was installed from a store (Play Store or F-Droid)
  static Future<bool> isFromStore() async {
    final source = await getInstallerSource();
    return source == 'com.android.vending' || source == 'org.fdroid.fdroid';
  }
}