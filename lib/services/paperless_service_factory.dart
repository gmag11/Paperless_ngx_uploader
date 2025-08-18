import 'dart:developer' as developer;
import '../models/server_config.dart';
import '../providers/server_manager.dart';
// import removed - no longer needed
import 'paperless_service.dart';

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

  PaperlessService _createServiceForServer(ServerConfig server) {
    return PaperlessService(
      baseUrl: server.serverUrl,
      username: server.username ?? '',
      password: '', // Password will be loaded from secure storage
      useApiToken: server.authMethod == AuthMethod.apiToken,
      apiToken: server.apiToken,
      allowSelfSignedCertificates: server.allowSelfSignedCertificates,
    );
  }

  Future<PaperlessService?> createServiceWithCredentials() async {
    final server = _serverManager.selectedServer;
    if (server == null) {
      return null;
    }

    final credentials = await _serverManager.getServerCredentials(server.id);
    
    return PaperlessService(
      baseUrl: server.serverUrl,
      username: server.username ?? '',
      password: credentials['password'] ?? '',
      useApiToken: server.authMethod == AuthMethod.apiToken,
      apiToken: credentials['apiToken'] ?? server.apiToken,
      allowSelfSignedCertificates: server.allowSelfSignedCertificates,
    );
  }

  Future<PaperlessService?> createServiceForServerWithCredentials(String serverId) async {
    final server = _serverManager.getServer(serverId);
    if (server == null) {
      return null;
    }

    final credentials = await _serverManager.getServerCredentials(serverId);
    
    return PaperlessService(
      baseUrl: server.serverUrl,
      username: server.username ?? '',
      password: credentials['password'] ?? '',
      useApiToken: server.authMethod == AuthMethod.apiToken,
      apiToken: credentials['apiToken'] ?? server.apiToken,
      allowSelfSignedCertificates: server.allowSelfSignedCertificates,
    );
  }
}