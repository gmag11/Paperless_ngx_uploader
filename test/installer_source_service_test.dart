import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/services/installer_source_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstallerSourceService', () {
    const channel = MethodChannel('installer_source');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null; // Default mock returns null
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getInstallerSource returns correct package name', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'com.android.vending';
      });

      final result = await InstallerSourceService.getInstallerSource();
      expect(result, equals('com.android.vending'));
    });

    test('getInstallerSource returns null when not available', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

      final result = await InstallerSourceService.getInstallerSource();
      expect(result, isNull);
    });

    test('isFromPlayStore returns true for Play Store', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'com.android.vending';
      });

      final result = await InstallerSourceService.isFromPlayStore();
      expect(result, isTrue);
    });

    test('isFromPlayStore returns false for non-Play Store', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'org.fdroid.fdroid';
      });

      final result = await InstallerSourceService.isFromPlayStore();
      expect(result, isFalse);
    });

    test('isFromFDroid returns true for F-Droid', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'org.fdroid.fdroid';
      });

      final result = await InstallerSourceService.isFromFDroid();
      expect(result, isTrue);
    });

    test('isFromFDroid returns false for non-F-Droid', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'com.android.vending';
      });

      final result = await InstallerSourceService.isFromFDroid();
      expect(result, isFalse);
    });

    test('isFromStore returns true for Play Store', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'com.android.vending';
      });

      final result = await InstallerSourceService.isFromStore();
      expect(result, isTrue);
    });

    test('isFromStore returns true for F-Droid', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'org.fdroid.fdroid';
      });

      final result = await InstallerSourceService.isFromStore();
      expect(result, isTrue);
    });

    test('isFromStore returns false for other sources', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return 'com.example.installer';
      });

      final result = await InstallerSourceService.isFromStore();
      expect(result, isFalse);
    });

    test('isFromStore returns false when installer source is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

      final result = await InstallerSourceService.isFromStore();
      expect(result, isFalse);
    });

    test('handles PlatformException gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(code: 'ERROR', message: 'Test error');
      });

      final result = await InstallerSourceService.getInstallerSource();
      expect(result, isNull);
    });
  });
}