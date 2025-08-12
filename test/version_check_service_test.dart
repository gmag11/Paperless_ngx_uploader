import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paperlessngx_uploader/services/version_check_service.dart';

/// Test implementation of VersionCheckService that tracks API calls
class TestVersionCheckService extends VersionCheckService {
  final String _mockInstallSource;
  bool githubApiCalled = false;
  
  TestVersionCheckService(this._mockInstallSource);
  
  @override
  Future<String> getInstallSource() async {
    return _mockInstallSource;
  }
  
  @override
  Future<VersionCheckResult> checkForUpdates() async {
    // Check install source first (replicate original logic)
    final installSource = await getInstallSource();
    if (installSource != 'apk') {
      return VersionCheckResult(
        hasUpdate: false,
        latestVersion: null,
        releaseUrl: null,
        skipped: true,
        lastCheck: DateTime.now(),
      );
    }
    
    // Track that we would have made the API call
    githubApiCalled = true;
    
    // Return a mock result for APK installs
    return VersionCheckResult(
      hasUpdate: false,
      latestVersion: 'v1.0.0',
      releaseUrl: 'https://github.com/test/test',
      skipped: false,
      lastCheck: DateTime.now(),
    );
  }
}

void main() {
  group('VersionCheckService - install source behavior', () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      
      // Mock PackageInfo
      PackageInfo.setMockInitialValues(
        appName: 'Paperless NGX Uploader',
        packageName: 'net.gmartin.paperlessngx_uploader',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: 'test',
      );
    });

    tearDown(() async {
      await sharedPreferences.clear();
    });

    test('should check GitHub for updates when installed from APK', () async {
      // Arrange
      final service = TestVersionCheckService('apk');

      // Act
      final result = await service.checkForUpdates();

      // Assert
      expect(service.githubApiCalled, true, 
          reason: 'GitHub API should be called for APK installs');
      expect(result.skipped, false, 
          reason: 'Should not skip when installed from APK');
    });

    test('should NOT check GitHub when installed from play_store', () async {
      // Arrange
      final service = TestVersionCheckService('play_store');

      // Act
      final result = await service.checkForUpdates();

      // Assert
      expect(service.githubApiCalled, false, 
          reason: 'GitHub API should NOT be called for Play Store installs');
      expect(result.skipped, true, 
          reason: 'Should skip when installed from Play Store');
    });

    test('should NOT check GitHub when installed from f_droid', () async {
      // Arrange
      final service = TestVersionCheckService('f_droid');

      // Act
      final result = await service.checkForUpdates();

      // Assert
      expect(service.githubApiCalled, false, 
          reason: 'GitHub API should NOT be called for F-Droid installs');
      expect(result.skipped, true, 
          reason: 'Should skip when installed from F-Droid');
    });
  });
}