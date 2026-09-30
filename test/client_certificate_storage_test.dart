import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> kv;
  late Directory dir;
  late SecureStorageService service;

  setUp(() async {
    kv = {};
    dir = await Directory.systemTemp.createTemp('cert_store_test');
    SecureStorageService.debugKvRead = (key) async => kv[key];
    SecureStorageService.debugKvWrite = (key, value) async => kv[key] = value;
    SecureStorageService.debugKvDelete = (key) async => kv.remove(key);
    SecureStorageService.debugCertificateDirectory = () async => dir;
    service = SecureStorageService();
  });

  tearDown(() async {
    SecureStorageService.debugKvRead = null;
    SecureStorageService.debugKvWrite = null;
    SecureStorageService.debugKvDelete = null;
    SecureStorageService.debugCertificateDirectory = null;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('small certificate material round-trips inline', () async {
    await service.saveServerClientCertificate('s1', [1, 2, 3, 4]);
    expect(await service.getServerClientCertificate('s1'), [1, 2, 3, 4]);
    expect(kv['server_s1_client_cert']!.startsWith('file:'), isFalse);

    await service.removeServerClientCertificateData('s1');
    expect(await service.getServerClientCertificate('s1'), isNull);
  });

  test('large certificate material falls back to an app-private file', () async {
    final big = List<int>.generate(5000, (i) => i % 256);
    await service.saveServerClientCertificate('s2', big);

    expect(kv['server_s2_client_cert']!.startsWith('file:'), isTrue);
    expect(dir.listSync(), isNotEmpty);
    expect(await service.getServerClientCertificate('s2'), big);

    await service.deleteServerClientCertificate('s2');
    expect(await service.getServerClientCertificate('s2'), isNull);
    expect(dir.listSync(), isEmpty);
  });

  test('certificate password and custom CA round-trip', () async {
    await service.saveServerClientCertificatePassword('s3', 'pw');
    await service.saveServerCustomCa('s3', [9, 9, 9]);

    expect(await service.getServerClientCertificatePassword('s3'), 'pw');
    expect(await service.getServerCustomCa('s3'), [9, 9, 9]);

    await service.removeServerClientCertificateData('s3');
    expect(await service.getServerClientCertificatePassword('s3'), isNull);
    expect(await service.getServerCustomCa('s3'), isNull);
  });
}
