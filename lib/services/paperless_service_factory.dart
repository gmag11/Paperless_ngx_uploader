import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../models/server_config.dart';
import '../models/server_transport_config.dart';
import '../providers/server_manager.dart';
import 'client_certificate.dart';
import 'paperless_service.dart';
import 'secure_storage_service.dart';

/// Single construction point for Paperless-NGX API clients.
///
/// Every call path must obtain its client from here so that per-server
/// transport settings (authentication, custom headers, TLS trust policy) are
/// applied uniformly. `test/centralized_http_client_guard_test.dart` enforces
/// that no other production file constructs a [PaperlessService] directly.
class PaperlessServiceFactory {
  final ServerManager _serverManager;
  final SecureStorageService _storage = SecureStorageService();

  PaperlessServiceFactory(this._serverManager);

  PaperlessService? createService() {
    final server = _serverManager.selectedServer;
    if (server == null) {
      developer.log('No server selected', name: 'PaperlessServiceFactory');
      return null;
    }

    return _createServiceForServer(server);
  }

  PaperlessService? createServiceForServer(String serverId) {
    final server = _serverManager.getServer(serverId);
    if (server == null) {
      developer.log('Server not found: $serverId', name: 'PaperlessServiceFactory');
      return null;
    }

    return _createServiceForServer(server);
  }

  /// Builds a client for a configuration that is not (yet) persisted, using
  /// credentials supplied by the caller (for example the server form).
  static PaperlessService createServiceForConfig(
    ServerConfig config, {
    String? password,
    String? apiToken,
    Dio? dio,
    ClientCertificateMaterial? clientCertificate,
  }) {
    return _createService(
      _transportFromConfig(
        config,
        password: password,
        apiToken: apiToken,
        clientCertificate: clientCertificate,
      ),
      dio: dio,
    );
  }

  Future<PaperlessService?> createServiceWithCredentials() async {
    final server = _serverManager.selectedServer;
    if (server == null) {
      return null;
    }

    final credentials = await _serverManager.getServerCredentials(server.id);
    final clientCertificate = await _loadClientCertificate(server);

    return _createService(_transportFromConfig(
      server,
      password: credentials['password'],
      apiToken: credentials['apiToken'],
      clientCertificate: clientCertificate,
    ));
  }

  Future<PaperlessService?> createServiceForServerWithCredentials(String serverId) async {
    final server = _serverManager.getServer(serverId);
    if (server == null) {
      return null;
    }

    final credentials = await _serverManager.getServerCredentials(serverId);
    final clientCertificate = await _loadClientCertificate(server);

    return _createService(_transportFromConfig(
      server,
      password: credentials['password'],
      apiToken: credentials['apiToken'],
      clientCertificate: clientCertificate,
    ));
  }

  /// Loads the client-certificate material for [server] from secure storage, or
  /// null when mutual TLS is not configured.
  Future<ClientCertificateMaterial?> _loadClientCertificate(ServerConfig server) async {
    if (!server.useClientCertificate) {
      return null;
    }
    final certificate = await _storage.getServerClientCertificate(server.id);
    if (certificate == null || certificate.isEmpty) {
      return null;
    }
    final isPem = server.clientCertificateFormat == ClientCertificateFormat.pem;
    return ClientCertificateMaterial(
      format: server.clientCertificateFormat,
      certificate: certificate,
      privateKey: isPem ? await _storage.getServerClientPrivateKey(server.id) : null,
      password: await _storage.getServerClientCertificatePassword(server.id),
      customCa: server.hasCustomCa
          ? await _storage.getServerCustomCa(server.id)
          : null,
    );
  }

  PaperlessService _createServiceForServer(ServerConfig server) {
    return _createService(_transportFromConfig(server));
  }

  /// Maps a server configuration to the transport settings of its client.
  /// This is the only place where that mapping happens.
  static ServerTransportConfig _transportFromConfig(
    ServerConfig config, {
    String? password,
    String? apiToken,
    ClientCertificateMaterial? clientCertificate,
  }) {
    return ServerTransportConfig(
      baseUrl: config.serverUrl,
      username: config.username ?? '',
      password: password ?? '',
      useApiToken: config.authMethod == AuthMethod.apiToken,
      apiToken: apiToken ?? config.apiToken,
      allowSelfSignedCertificates: config.allowSelfSignedCertificates,
      customHeaders: config.customHeaders,
      useClientCertificate: clientCertificate?.hasClientCertificate ?? false,
      clientCertificateFormat:
          clientCertificate?.format ?? config.clientCertificateFormat,
      clientCertificateBytes: clientCertificate?.certificate,
      clientPrivateKeyBytes: clientCertificate?.privateKey,
      clientCertificatePassword: clientCertificate?.password,
      customCaBytes: clientCertificate?.customCa,
    );
  }

  static PaperlessService _createService(
    ServerTransportConfig transport, {
    Dio? dio,
  }) {
    return PaperlessService(transport, dio: dio);
  }
}
