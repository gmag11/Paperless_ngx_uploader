import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../models/server_config.dart';
import '../models/server_transport_config.dart';
import '../providers/server_manager.dart';
import 'paperless_service.dart';

/// Single construction point for Paperless-NGX API clients.
///
/// Every call path must obtain its client from here so that per-server
/// transport settings (authentication, custom headers, TLS trust policy) are
/// applied uniformly. `test/centralized_http_client_guard_test.dart` enforces
/// that no other production file constructs a [PaperlessService] directly.
class PaperlessServiceFactory {
  final ServerManager _serverManager;

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
  }) {
    return _createService(
      _transportFromConfig(config, password: password, apiToken: apiToken),
      dio: dio,
    );
  }

  Future<PaperlessService?> createServiceWithCredentials() async {
    final server = _serverManager.selectedServer;
    if (server == null) {
      return null;
    }

    final credentials = await _serverManager.getServerCredentials(server.id);

    return _createService(_transportFromConfig(
      server,
      password: credentials['password'],
      apiToken: credentials['apiToken'],
    ));
  }

  Future<PaperlessService?> createServiceForServerWithCredentials(String serverId) async {
    final server = _serverManager.getServer(serverId);
    if (server == null) {
      return null;
    }

    final credentials = await _serverManager.getServerCredentials(serverId);

    return _createService(_transportFromConfig(
      server,
      password: credentials['password'],
      apiToken: credentials['apiToken'],
    ));
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
  }) {
    return ServerTransportConfig(
      baseUrl: config.serverUrl,
      username: config.username ?? '',
      password: password ?? '',
      useApiToken: config.authMethod == AuthMethod.apiToken,
      apiToken: apiToken ?? config.apiToken,
      allowSelfSignedCertificates: config.allowSelfSignedCertificates,
      customHeaders: config.customHeaders,
    );
  }

  static PaperlessService _createService(
    ServerTransportConfig transport, {
    Dio? dio,
  }) {
    return PaperlessService(transport, dio: dio);
  }
}
