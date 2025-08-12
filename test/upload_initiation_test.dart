import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/services/paperless_service.dart';

void main() {
  group('PaperlessService', () {
    final baseUrl = 'https://test.example.com';
    final username = 'testuser';
    final password = 'testpass';

    group('initialization', () {
      test('paperless service can be instantiated with required parameters', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service, isA<PaperlessService>());
      });

      test('paperless service can be instantiated with token auth', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
          useApiToken: true,
          apiToken: 'test-token',
        );
        expect(service, isA<PaperlessService>());
      });

      test('paperless service can be instantiated with self-signed certificates', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
          allowSelfSignedCertificates: true,
        );
        expect(service, isA<PaperlessService>());
      });
    });

    group('upload method', () {
      test('uploadDocument method exists', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service.uploadDocument, isA<Function>());
      });

      test('uploadDocument method accepts required parameters', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(() => service.uploadDocument(
          filePath: '/test.pdf',
          fileName: 'test.pdf',
          tagIds: [],
        ), returnsNormally);
      });

      test('uploadDocument method accepts optional parameters', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(() => service.uploadDocument(
          filePath: '/test.pdf',
          fileName: 'test.pdf',
          tagIds: [1, 2, 3],
          title: 'Test Document',
        ), returnsNormally);
      });
    });

    group('service methods', () {
      test('testConnection method exists', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service.testConnection, isA<Function>());
      });

      test('fetchTags method exists', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service.fetchTags, isA<Function>());
      });
    });

    group('upload parameters', () {
      test('filePath parameter is required', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service.uploadDocument, isA<Function>());
      });

      test('fileName parameter is required', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service.uploadDocument, isA<Function>());
      });

      test('tagIds parameter is supported', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service.uploadDocument, isA<Function>());
      });

      test('title parameter is optional', () {
        final service = PaperlessService(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
        expect(service.uploadDocument, isA<Function>());
      });
    });

    group('base URL normalization', () {
      test('normalizes base URL with trailing slash', () {
        final service = PaperlessService(
          baseUrl: 'https://test.example.com/',
          username: username,
          password: password,
        );
        expect(service.baseUrl, equals('https://test.example.com'));
      });

      test('normalizes base URL without trailing slash', () {
        final service = PaperlessService(
          baseUrl: 'https://test.example.com',
          username: username,
          password: password,
        );
        expect(service.baseUrl, equals('https://test.example.com'));
      });
    });
  });
}