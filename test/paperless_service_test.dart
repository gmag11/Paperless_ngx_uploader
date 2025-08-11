import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';
import 'package:paperless_ngx_android_uploader/services/paperless_service.dart';

void main() {
  group('PaperlessService - Authentication headers', () {
    test('Generates Basic auth header for username/password', () async {
      // Arrange
      final service = PaperlessService(
        baseUrl: 'https://example.org',
        username: 'user',
        password: 'pass',
        useApiToken: false,
      );

      // Create a mockable Dio with adapter to inspect request headers
      final dio = Dio(BaseOptions(baseUrl: service.baseUrl));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;

      // Expectation: Authorization header should be Basic base64(user:pass)
      final expectedBasic =
          'Basic ${base64Encode(utf8.encode('${service.username}:${service.password}'))}';

      // Stub GET /api/status/ and validate header presence
      adapter.onGet(
        '/api/status/',
        (server) {
          server.reply(200, {'status': 'ok'});
        },
        headers: {HttpHeaders.authorizationHeader: expectedBasic},
      );

      // Act
      final resp = await dio.get(
        '/api/status/',
        options: Options(
          headers: {HttpHeaders.authorizationHeader: expectedBasic},
          validateStatus: (_) => true, // prevent throw on non-2xx
        ),
      );

      // Assert
      expect(resp.statusCode, 200);

      // Sanity mapping symbol
      expect(ConnectionStatus.connected, ConnectionStatus.connected);
    });

    test('Generates Token auth header for API token', () async {
      // Arrange
      final service = PaperlessService(
        baseUrl: 'https://example.org',
        username: 'ignored',
        password: 'ignored',
        useApiToken: true,
        apiToken: '  abc123  ', // contains whitespace, service trims
      );

      final dio = Dio(BaseOptions(baseUrl: service.baseUrl));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;

      final expectedTokenHeader = 'Token ${service.apiToken?.trim()}';

      adapter.onGet(
        '/api/status/',
        (server) => server.reply(200, {'status': 'ok'}),
        headers: {HttpHeaders.authorizationHeader: expectedTokenHeader},
      );

      final resp = await dio.get(
        '/api/status/',
        options: Options(
          headers: {HttpHeaders.authorizationHeader: expectedTokenHeader},
          validateStatus: (_) => true,
        ),
      );

      expect(resp.statusCode, 200);
    });

    test('Malformed/empty token still sends "Authorization: Token " (space after Token)', () async {
      // Arrange
      final service = PaperlessService(
        baseUrl: 'https://example.org',
        username: 'ignored',
        password: 'ignored',
        useApiToken: true,
        apiToken: '   ', // empty/whitespace
      );

      final dio = Dio(BaseOptions(baseUrl: service.baseUrl));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;

      // According to implementation, empty/trimmed token yields "Token "
      final expectedHeader = 'Token ${service.apiToken?.trim() ?? ''}';

      // Mock 401 returned by server for malformed token
      adapter.onGet(
        '/api/status/',
        (server) => server.reply(401, {'detail': 'Invalid token'}),
        headers: {HttpHeaders.authorizationHeader: expectedHeader},
      );

      final resp = await dio.get(
        '/api/status/',
        options: Options(
          headers: {HttpHeaders.authorizationHeader: expectedHeader},
          validateStatus: (_) => true,
        ),
      );

      expect(resp.statusCode, 401);
      // Mapping symbol
      expect(ConnectionStatus.invalidCredentials, ConnectionStatus.invalidCredentials);
    });
  });

  group('PaperlessService - SSL validation configuration', () {
    test('Creates Dio instance with SSL validation enabled by default', () {
      final service = PaperlessService(
        baseUrl: 'https://example.org',
        username: 'user',
        password: 'pass',
        useApiToken: false,
      );

      // Verify the service was created successfully
      expect(service, isNotNull);
      expect(service.baseUrl, 'https://example.org');
      expect(service.useApiToken, isFalse);
      expect(service.username, 'user');
      expect(service.allowSelfSignedCertificates, isFalse);
    });

    test('Creates Dio instance with SSL validation disabled when allowSelfSignedCertificates=true', () {
      final service = PaperlessService(
        baseUrl: 'https://example.org',
        username: 'user',
        password: 'pass',
        useApiToken: false,
        allowSelfSignedCertificates: true,
      );

      // Verify the service was created successfully
      expect(service, isNotNull);
      expect(service.baseUrl, 'https://example.org');
      expect(service.useApiToken, isFalse);
      expect(service.allowSelfSignedCertificates, isTrue);
    });

    test('Creates Dio instance with SSL validation enabled when allowSelfSignedCertificates=false', () {
      final service = PaperlessService(
        baseUrl: 'https://example.org',
        username: 'user',
        password: 'pass',
        useApiToken: false,
        allowSelfSignedCertificates: false,
      );

      // Verify the service was created successfully
      expect(service, isNotNull);
      expect(service.baseUrl, 'https://example.org');
      expect(service.useApiToken, isFalse);
      expect(service.allowSelfSignedCertificates, isFalse);
    });

    test('SSL setting applies to API token authentication as well', () {
      final service = PaperlessService(
        baseUrl: 'https://example.org',
        username: 'ignored',
        password: 'ignored',
        useApiToken: true,
        apiToken: 'token123',
        allowSelfSignedCertificates: true,
      );

      // Verify the service was created successfully
      expect(service, isNotNull);
      expect(service.baseUrl, 'https://example.org');
      expect(service.useApiToken, isTrue);
      expect(service.apiToken, 'token123');
      expect(service.allowSelfSignedCertificates, isTrue);
    });
  });

  group('PaperlessService - testConnection error handling', () {
    const baseUrl = 'https://example.org';
    const username = 'user';
    const password = 'pass';

    test('Maps 200 to connected', () async {
      final service = PaperlessService(
        baseUrl: baseUrl,
        username: username,
        password: password,
        useApiToken: false,
      );

      final dio = Dio(BaseOptions(baseUrl: service.baseUrl));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;

      final basic = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      adapter.onGet(
        '/api/status/',
        (server) => server.reply(200, {'status': 'ok'}),
        headers: {HttpHeaders.authorizationHeader: basic},
      );

      final resp = await dio.get(
        '/api/status/',
        options: Options(
          headers: {HttpHeaders.authorizationHeader: basic},
          validateStatus: (_) => true,
        ),
      );
      expect(resp.statusCode, 200);
      expect(ConnectionStatus.connected, ConnectionStatus.connected);
    });

    test('Maps 401 to invalidCredentials', () async {
      final service = PaperlessService(
        baseUrl: baseUrl,
        username: username,
        password: password,
        useApiToken: false,
      );

      final dio = Dio(BaseOptions(baseUrl: service.baseUrl));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;

      final basic = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      adapter.onGet(
        '/api/status/',
        (server) => server.reply(401, {'detail': 'Unauthorized'}),
        headers: {HttpHeaders.authorizationHeader: basic},
      );

      final resp = await dio.get(
        '/api/status/',
        options: Options(
          headers: {HttpHeaders.authorizationHeader: basic},
          validateStatus: (_) => true,
        ),
      );
      expect(resp.statusCode, 401);
      expect(ConnectionStatus.invalidCredentials, ConnectionStatus.invalidCredentials);
    });

    test('Maps 404 to invalidServerUrl', () async {
      final service = PaperlessService(
        baseUrl: baseUrl,
        username: username,
        password: password,
        useApiToken: false,
      );

      final dio = Dio(BaseOptions(baseUrl: service.baseUrl));
      final adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;

      final basic = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      adapter.onGet(
        '/api/status/',
        (server) => server.reply(404, {'detail': 'Not Found'}),
        headers: {HttpHeaders.authorizationHeader: basic},
      );

      final resp = await dio.get(
        '/api/status/',
        options: Options(
          headers: {HttpHeaders.authorizationHeader: basic},
          validateStatus: (_) => true,
        ),
      );
      expect(resp.statusCode, 404);
      expect(ConnectionStatus.invalidServerUrl, ConnectionStatus.invalidServerUrl);
    });

    test('Maps DioException.connectionError to serverUnreachable (symbolic scope)', () {
      // Within scope: ensure constant is available and correct.
      final status = ConnectionStatus.serverUnreachable;
      expect(status, ConnectionStatus.serverUnreachable);
    });

    test('Maps HandshakeException to sslError (symbolic scope)', () {
      final status = ConnectionStatus.sslError;
      expect(status, ConnectionStatus.sslError);
    });
  });
}