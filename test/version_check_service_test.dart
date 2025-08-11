import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperless_ngx_android_uploader/services/version_check_service.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late VersionCheckService versionCheckService;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    versionCheckService = VersionCheckService();
    
    // Initialize SharedPreferences with test values
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    
    // Mock PackageInfo
    PackageInfo.setMockInitialValues(
      appName: 'Paperless NGX Uploader',
      packageName: 'net.gmartin.paperlessngx_uploader',
      version: '1.6.2',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('VersionCheckService', () {
    test('skips version check when installed from Play Store', () async {
      // Mock InstallerSourceService.isFromStore to return true
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('installer_source'),
        (call) async => 'com.android.vending',
      );

      final result = await versionCheckService.checkForUpdates();
      
      expect(result.skipped, isTrue);
      expect(result.hasUpdate, isFalse);
      expect(result.latestVersion, isNull);
      expect(result.releaseUrl, isNull);
    });

    test('skips version check when installed from F-Droid', () async {
      // Mock InstallerSourceService.isFromStore to return true for F-Droid
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('installer_source'),
        (call) async => 'org.fdroid.fdroid',
      );

      final result = await versionCheckService.checkForUpdates();
      
      expect(result.skipped, isTrue);
      expect(result.hasUpdate, isFalse);
      expect(result.latestVersion, isNull);
      expect(result.releaseUrl, isNull);
    });

    test('performs version check when installed from other sources', () async {
      // Mock InstallerSourceService.isFromStore to return false
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('installer_source'),
        (call) async => 'com.example.installer',
      );

      // Reset last check to allow the test to run
      await versionCheckService.resetLastCheckTimestamp();

      final result = await versionCheckService.checkForUpdates();
      
      // Since we can't easily mock http.get, we'll check if it's not skipped
      // The actual API call will fail, but it shouldn't be skipped due to store
      expect(result.skipped, isFalse);
    });

    test('skips version check when checked within 24 hours', () async {
      // Mock InstallerSourceService.isFromStore to return false
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('installer_source'),
        (call) async => 'com.example.installer',
      );

      // Set last check timestamp to now
      final now = DateTime.now();
      await sharedPreferences.setInt('last_version_check_timestamp', now.millisecondsSinceEpoch);

      final result = await versionCheckService.checkForUpdates();
      
      expect(result.skipped, isTrue);
      expect(result.hasUpdate, isFalse);
    });

    test('handles API errors gracefully', () async {
      // Mock InstallerSourceService.isFromStore to return false
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('installer_source'),
        (call) async => 'com.example.installer',
      );

      // Reset last check to allow the test to run
      await versionCheckService.resetLastCheckTimestamp();

      // The actual HTTP call will fail since we're not mocking it properly
      // But we can verify the error handling
      final result = await versionCheckService.checkForUpdates();
      
      expect(result.error, isNotNull);
      expect(result.hasUpdate, isFalse);
    });

    test('resetLastCheckTimestamp removes the timestamp', () async {
      // Set a timestamp first
      final now = DateTime.now();
      await sharedPreferences.setInt('last_version_check_timestamp', now.millisecondsSinceEpoch);
      
      // Verify it exists
      expect(sharedPreferences.containsKey('last_version_check_timestamp'), isTrue);
      
      // Reset it
      await versionCheckService.resetLastCheckTimestamp();
      
      // Verify it's gone
      expect(sharedPreferences.containsKey('last_version_check_timestamp'), isFalse);
    });

    test('getLastCheckTimestamp returns null when no check performed', () async {
      final timestamp = await versionCheckService.getLastCheckTimestamp();
      expect(timestamp, isNull);
    });

    test('getLastCheckTimestamp returns correct timestamp', () async {
      final now = DateTime.now();
      await sharedPreferences.setInt('last_version_check_timestamp', now.millisecondsSinceEpoch);
      
      final timestamp = await versionCheckService.getLastCheckTimestamp();
      expect(timestamp, isNotNull);
      expect(timestamp!.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });
  });

  group('VersionCheckResult', () {
    test('toString returns correct message for skipped check', () {
      final result = VersionCheckResult(
        hasUpdate: false,
        latestVersion: null,
        releaseUrl: null,
        skipped: true,
        lastCheck: DateTime.now(),
      );
      
      expect(result.toString(), contains('skipped'));
    });

    test('toString returns correct message for error', () {
      final result = VersionCheckResult(
        hasUpdate: false,
        latestVersion: null,
        releaseUrl: null,
        skipped: false,
        lastCheck: DateTime.now(),
        error: 'Test error',
      );
      
      expect(result.toString(), contains('failed'));
      expect(result.toString(), contains('Test error'));
    });

    test('toString returns correct message for available update', () {
      final result = VersionCheckResult(
        hasUpdate: true,
        latestVersion: 'v1.7.0',
        releaseUrl: 'https://example.com',
        skipped: false,
        lastCheck: DateTime.now(),
      );
      
      expect(result.toString(), contains('Update available'));
      expect(result.toString(), contains('v1.7.0'));
    });

    test('toString returns correct message for no updates', () {
      final result = VersionCheckResult(
        hasUpdate: false,
        latestVersion: 'v1.6.2',
        releaseUrl: 'https://example.com',
        skipped: false,
        lastCheck: DateTime.now(),
      );
      
      expect(result.toString(), contains('No updates available'));
    });
  });
}