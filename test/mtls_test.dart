import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/models/connection_status.dart';
import 'package:paperlessngx_uploader/models/server_config.dart';
import 'package:paperlessngx_uploader/models/server_transport_config.dart';
import 'package:paperlessngx_uploader/services/client_certificate.dart';
import 'package:paperlessngx_uploader/services/paperless_service.dart';

List<int> _fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

/// Starts an in-process TLS server that requires a client certificate signed by
/// the throwaway test CA, and answers every request with a 200 JSON body.
Future<SecureServerSocket> _startTlsServer() async {
  final context = SecurityContext()
    ..useCertificateChainBytes(_fixture('server.crt'))
    ..usePrivateKeyBytes(_fixture('server.key'))
    ..setTrustedCertificatesBytes(_fixture('ca.crt'));

  final server = await SecureServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
    context,
    requireClientCertificate: true,
  );

  server.listen((socket) {
    socket.listen(
      (_) {
        const body = '{"id":1}';
        socket.write('HTTP/1.1 200 OK\r\n'
            'Content-Type: application/json\r\n'
            'Content-Length: ${body.length}\r\n'
            'Connection: close\r\n\r\n$body');
        socket.close();
      },
      onError: (_) {},
      cancelOnError: true,
    );
  }, onError: (_) {});

  return server;
}

void main() {
  // No TestWidgetsFlutterBinding here: it installs HttpOverrides that block real
  // network connections, which this test needs.
  late SecureServerSocket server;
  late int port;

  setUp(() async {
    server = await _startTlsServer();
    port = server.port;
  });

  tearDown(() async {
    await server.close();
  });

  PaperlessService service({
    required bool withClientCertificate,
    String? password,
  }) {
    return PaperlessService(ServerTransportConfig(
      baseUrl: 'https://127.0.0.1:$port',
      username: 'u',
      password: 'p',
      useClientCertificate: withClientCertificate,
      clientCertificateFormat: ClientCertificateFormat.pkcs12,
      clientCertificateBytes: withClientCertificate ? _fixture('client.p12') : null,
      clientCertificatePassword: password,
      customCaBytes: _fixture('ca.crt'),
    ));
  }

  test('a server requiring a client certificate accepts the configured one',
      () async {
    final status = await service(withClientCertificate: true, password: 'testpass')
        .testConnection();
    expect(status, ConnectionStatus.connected);
  });

  test('connecting without a client certificate is rejected', () async {
    final status = await service(withClientCertificate: false).testConnection();
    expect(status, isNot(ConnectionStatus.connected));
  });

  test('a client certificate pasted as PEM text is accepted', () async {
    final certificate = decodePastedCertificate(
        utf8.decode(_fixture('client.crt')), ClientCertificateFormat.pem);
    final privateKey = decodePastedCertificate(
        utf8.decode(_fixture('client.key')), ClientCertificateFormat.pem);

    final service = PaperlessService(ServerTransportConfig(
      baseUrl: 'https://127.0.0.1:$port',
      username: 'u',
      password: 'p',
      useClientCertificate: true,
      clientCertificateFormat: ClientCertificateFormat.pem,
      clientCertificateBytes: certificate,
      clientPrivateKeyBytes: privateKey,
      customCaBytes: _fixture('ca.crt'),
    ));

    expect(await service.testConnection(), ConnectionStatus.connected);
  });

  test('a non-certificate file is reported as an invalid certificate, not a '
      'password problem', () async {
    final service = PaperlessService(ServerTransportConfig(
      baseUrl: 'https://127.0.0.1:$port',
      username: 'u',
      password: 'p',
      useClientCertificate: true,
      clientCertificateFormat: ClientCertificateFormat.pkcs12,
      clientCertificateBytes: utf8.encode('this is not a certificate'),
      clientCertificatePassword: 'whatever',
      customCaBytes: _fixture('ca.crt'),
    ));

    expect(await service.testConnection(), ConnectionStatus.clientCertificateError);
  });

  test('a wrong certificate password is reported as a certificate problem',
      () async {
    final status = await service(withClientCertificate: true, password: 'wrong')
        .testConnection();
    expect(status, ConnectionStatus.clientCertificatePasswordError);
  });
}
