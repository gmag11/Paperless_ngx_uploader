import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/models/server_config.dart';
import 'package:paperlessngx_uploader/models/server_transport_config.dart';
import 'package:paperlessngx_uploader/services/paperless_service.dart';
import 'package:paperlessngx_uploader/services/paperless_service_factory.dart';

/// Minimal adapter that records every outgoing request and returns a canned
/// JSON response, so tests can assert what actually reaches the transport.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({Map<String, dynamic>? body})
      : body = body ?? const {'results': <dynamic>[], 'next': null};

  final List<RequestOptions> requests = [];
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String? _header(RequestOptions request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString();
    }
  }
  return null;
}

PaperlessService _serviceFor(
  _RecordingAdapter adapter, {
  Map<String, String>? customHeaders,
  bool useApiToken = false,
  String? apiToken,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return PaperlessService(
    ServerTransportConfig(
      baseUrl: 'https://paperless.example',
      username: 'alice',
      password: 's3cret',
      useApiToken: useApiToken,
      apiToken: apiToken,
      customHeaders: customHeaders,
    ),
    dio: dio,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Uniform transport configuration', () {
    test('custom headers and basic auth reach the wire on testConnection',
        () async {
      final adapter = _RecordingAdapter(body: const {'id': 1});
      final service = _serviceFor(
        adapter,
        customHeaders: const {'X-Proxy-Auth': 'secret'},
      );

      await service.testConnection();

      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(_header(request, 'X-Proxy-Auth'), 'secret');
      expect(_header(request, 'authorization'), startsWith('Basic '));
    });

    test('custom headers reach the wire on fetchTags', () async {
      final adapter = _RecordingAdapter();
      final service = _serviceFor(
        adapter,
        customHeaders: const {'X-Proxy-Auth': 'secret'},
      );

      await service.fetchTags();

      expect(adapter.requests, isNotEmpty);
      expect(_header(adapter.requests.first, 'X-Proxy-Auth'), 'secret');
    });

    test('API token authentication reaches the wire', () async {
      final adapter = _RecordingAdapter(body: const {'id': 1});
      final service = _serviceFor(
        adapter,
        useApiToken: true,
        apiToken: 'tok-123',
      );

      await service.testConnection();

      expect(_header(adapter.requests.single, 'authorization'), 'Token tok-123');
    });

    test('both protocol-detection attempts carry the same transport rules',
        () async {
      // The dialog builds an HTTPS and an HTTP draft through the factory; both
      // must carry the typed credentials and custom headers.
      Future<PaperlessService> draft(String url) async {
        final adapter = _RecordingAdapter(body: const {'id': 1});
        final service = PaperlessServiceFactory.createServiceForConfig(
          ServerConfig(
            id: 'draft',
            name: 'draft',
            serverUrl: url,
            authMethod: AuthMethod.usernamePassword,
            username: 'alice',
            customHeaders: const {'X-Proxy-Auth': 'secret'},
          ),
          password: 's3cret',
          dio: Dio()..httpClientAdapter = adapter,
        );
        await service.testConnection();
        expect(_header(adapter.requests.single, 'X-Proxy-Auth'), 'secret');
        return service;
      }

      await draft('https://paperless.example');
      await draft('http://paperless.example');
    });
  });

  group('Factory mapping', () {
    test('draft config maps auth method, token and custom headers', () {
      final service = PaperlessServiceFactory.createServiceForConfig(
        ServerConfig(
          id: '1',
          name: 'server',
          serverUrl: 'https://paperless.example',
          authMethod: AuthMethod.apiToken,
          customHeaders: const {'X-Proxy-Auth': 'secret'},
        ),
        apiToken: 'tok-123',
      );

      expect(service.useApiToken, isTrue);
      expect(service.apiToken, 'tok-123');
      expect(service.customHeaders, const {'X-Proxy-Auth': 'secret'});
    });
  });

  group('TLS trust policy', () {
    test('self-signed option configures the native adapter', () {
      final allowed = PaperlessServiceFactory.createServiceForConfig(
        ServerConfig(
          id: '1',
          name: 'server',
          serverUrl: 'https://paperless.example',
          authMethod: AuthMethod.usernamePassword,
          username: 'alice',
          allowSelfSignedCertificates: true,
        ),
        password: 's3cret',
      );
      expect(allowed.allowSelfSignedCertificates, isTrue);
      final adapter = allowed.dio.httpClientAdapter as IOHttpClientAdapter;
      expect(adapter.createHttpClient, isNotNull);

      final strict = PaperlessServiceFactory.createServiceForConfig(
        ServerConfig(
          id: '2',
          name: 'server',
          serverUrl: 'https://paperless.example',
          authMethod: AuthMethod.usernamePassword,
          username: 'alice',
        ),
        password: 's3cret',
      );
      expect(strict.allowSelfSignedCertificates, isFalse);
      final strictAdapter = strict.dio.httpClientAdapter as IOHttpClientAdapter;
      expect(strictAdapter.createHttpClient, isNull);
    });
  });
}
