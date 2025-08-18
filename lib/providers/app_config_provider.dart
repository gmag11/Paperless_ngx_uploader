import 'package:flutter/material.dart';
// import removed - no longer needed
import '../models/server_config.dart';
import '../services/paperless_service.dart' as paperless;
import '../providers/server_manager.dart';
import '../services/secure_storage_service.dart';
import '../models/connection_status.dart';
import '../services/paperless_service_factory.dart';

typedef StringCallback = String Function(String key);

class AppConfigProvider extends ChangeNotifier {
  final ServerManager _serverManager;
  final SecureStorageService _storageService = SecureStorageService();
  final StringCallback? _translate;

  AppConfigProvider(this._serverManager, {StringCallback? translate}) : _translate = translate {
    _serverManager.addListener(_onServerChanged);
  }

  @override
  void dispose() {
    _serverManager.removeListener(_onServerChanged);
    super.dispose();
  }

  void _onServerChanged() {
    notifyListeners();
  }

  // Backward compatibility properties
  String? get serverUrl => _serverManager.selectedServer?.serverUrl;
  bool get isConfigured => _serverManager.selectedServer != null;
  String? get serverName => _serverManager.selectedServer?.name;
  
  // Authentication properties
  AuthMethod get authMethod => _serverManager.selectedServer?.authMethod ?? AuthMethod.usernamePassword;
  String? get username => _serverManager.selectedServer?.username;
  String? get password => null; // Always null for security
  String? get apiToken => null; // Always null for security
  bool get allowSelfSignedCertificates => _serverManager.selectedServer?.allowSelfSignedCertificates ?? false;

  // Connection status and error
  ConnectionStatus _connectionStatus = ConnectionStatus.notConfigured;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? _connectionError;
  String? get connectionError => _connectionError;

  // Delegated methods
  Future<void> loadConfiguration() async {
    await _serverManager.refresh();
  }

  // Backward compatibility method with positional arguments
  Future<void> saveConfiguration(String serverUrl, String username, String secret) async {
    final server = _serverManager.selectedServer;
    if (server != null) {
      final updatedServer = ServerConfig(
        id: server.id,
        name: server.name,
        serverUrl: serverUrl,
        authMethod: username.isEmpty ? AuthMethod.apiToken : AuthMethod.usernamePassword,
        username: username.isEmpty ? null : username,
        apiToken: username.isEmpty ? secret : null,
        allowSelfSignedCertificates: server.allowSelfSignedCertificates,
      );
      
      await _serverManager.updateServer(updatedServer);
      
      if (username.isNotEmpty) {
        await _serverManager.saveServerCredentials(server.id, username: username, password: secret);
      } else {
        await _serverManager.saveServerApiToken(server.id, apiToken: secret);
      }
    }
  }

  Future<void> setAllowSelfSignedCertificates(bool allow) async {
    final server = _serverManager.selectedServer;
    if (server != null) {
      final updatedServer = ServerConfig(
        id: server.id,
        name: server.name,
        serverUrl: server.serverUrl,
        authMethod: server.authMethod,
        username: server.username,
        apiToken: server.apiToken,
        allowSelfSignedCertificates: allow,
      );
      await _serverManager.updateServer(updatedServer);
    }
  }

  Future<void> clearConfiguration() async {
    notifyListeners();
  }

  Future<paperless.PaperlessService?> getPaperlessService() async {
    return _serverManager.selectedServer != null
        ? await PaperlessServiceFactory(_serverManager).createServiceWithCredentials()
        : null;
  }

  // Selected tags management
  List<int> get selectedTags {
    final server = _serverManager.selectedServer;
    if (server == null) return [];
    // This is a synchronous getter - we'll need to handle async loading elsewhere
    return [];
  }
  
  Future<List<int>> getSelectedTags() async {
    final server = _serverManager.selectedServer;
    if (server == null) return [];
    return await _storageService.getServerSelectedTags(server.id);
  }

  Future<void> loadStoredTags() async {
    // Tags are loaded on demand via getSelectedTags
    notifyListeners();
  }

  Future<void> setSelectedTags(List<int> tagIds) async {
    final server = _serverManager.selectedServer;
    if (server != null) {
      await _storageService.saveServerSelectedTags(server.id, tagIds);
    }
  }

  Future<void> addSelectedTag(int tagId) async {
    final server = _serverManager.selectedServer;
    if (server != null) {
      final currentTags = await _storageService.getServerSelectedTags(server.id);
      if (!currentTags.contains(tagId)) {
        currentTags.add(tagId);
        await _storageService.saveServerSelectedTags(server.id, currentTags);
      }
    }
  }

  Future<void> removeSelectedTag(int tagId) async {
    final server = _serverManager.selectedServer;
    if (server != null) {
      final currentTags = await _storageService.getServerSelectedTags(server.id);
      currentTags.remove(tagId);
      await _storageService.saveServerSelectedTags(server.id, currentTags);
    }
  }

  // Testing connection
  Future<void> testConnection() async {
    _connectionStatus = ConnectionStatus.connecting;
    _connectionError = null;
    notifyListeners();

    final service = await getPaperlessService();
    if (service != null) {
      try {
        await service.fetchTags();
        _connectionStatus = ConnectionStatus.connected;
      } catch (e) {
        _connectionStatus = ConnectionStatus.unknownError;
        _connectionError = e.toString();
      }
    } else {
      _connectionStatus = ConnectionStatus.notConfigured;
      _connectionError = 'No server configured';
    }
    
    notifyListeners();
  }

  String translate(String key) {
    return _translate?.call(key) ?? key;
  }

  // Delegation methods
  ServerManager get serverManager => _serverManager;

  Future<Map<String, String?>> getCurrentCredentials() async {
    final server = _serverManager.selectedServer;
    if (server == null) {
      return {
        'serverUrl': '',
        'username': '',
        'password': '',
        'apiToken': '',
        'authMethod': 'usernamePassword',
      };
    }

    final credentials = await _serverManager.getServerCredentials(server.id);
    final authToken = await _serverManager.getServerApiToken(server.id);
    
    return {
      'serverUrl': server.serverUrl,
      'username': server.username ?? '',
      'password': credentials['password'] ?? '',
      'apiToken': authToken ?? '',
      'authMethod': server.authMethod.name,
    };
  }
}