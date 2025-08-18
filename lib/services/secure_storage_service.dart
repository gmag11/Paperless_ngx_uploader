import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
  // Server-specific keys
  static String _serverPasswordKey(String serverId) => 'server_${serverId}_password';
  static String _serverApiTokenKey(String serverId) => 'server_${serverId}_api_token';
  static String _serverSelectedTagsKey(String serverId) => 'server_${serverId}_selected_tags';
  
  // Server list management keys
  static const _serversKey = 'servers';
  static const _selectedServerKey = 'selected_server_id';

  // Server-specific methods
  Future<void> saveServerCredentials(String serverId, String username, String password) async {
    await _storage.write(key: _serverPasswordKey(serverId), value: password);
  }

  Future<void> saveServerApiToken(String serverId, String apiToken) async {
    await _storage.write(key: _serverApiTokenKey(serverId), value: apiToken);
  }

  Future<String?> getServerCredentials(String serverId) async {
    return await _storage.read(key: _serverPasswordKey(serverId));
  }

  Future<String?> getServerApiToken(String serverId) async {
    return await _storage.read(key: _serverApiTokenKey(serverId));
  }

  @Deprecated('Use ServerConfig.defaultTagIds instead of separate tag storage')
  Future<void> saveServerSelectedTags(String serverId, List<int> tagIds) async {
    final key = _serverSelectedTagsKey(serverId);
    await _storage.write(key: key, value: jsonEncode(tagIds));
  }

  @Deprecated('Use ServerConfig.defaultTagIds instead of separate tag storage')
  Future<List<int>> getServerSelectedTags(String serverId) async {
    final key = _serverSelectedTagsKey(serverId);
    final tagsJson = await _storage.read(key: key);
    if (tagsJson == null) return [];
    
    try {
      final List<dynamic> tagsList = jsonDecode(tagsJson) as List<dynamic>;
      return tagsList.map((id) => id as int).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clean up legacy tag storage for a server
  Future<void> cleanupLegacyTagStorage(String serverId) async {
    final key = _serverSelectedTagsKey(serverId);
    await _storage.delete(key: key);
  }

  Future<void> saveServers(List<Map<String, dynamic>> servers) async {
    developer.log('Saving ${servers.length} servers to secure storage', name: 'SecureStorageService');
    await _storage.write(key: _serversKey, value: jsonEncode(servers));
    developer.log('Servers saved successfully', name: 'SecureStorageService');
  }

  Future<List<Map<String, dynamic>>> getServers() async {
    final serversJson = await _storage.read(key: _serversKey);
    if (serversJson == null) {
      developer.log('No servers found in secure storage', name: 'SecureStorageService');
      return [];
    }
    
    try {
      final List<dynamic> serversList = jsonDecode(serversJson) as List<dynamic>;
      final servers = serversList.map((server) => Map<String, dynamic>.from(server as Map<String, dynamic>)).toList();
      developer.log('Loaded ${servers.length} servers from secure storage', name: 'SecureStorageService');
      return servers;
    } catch (e) {
      developer.log('Error loading servers: $e', name: 'SecureStorageService');
      return [];
    }
  }

  Future<void> saveSelectedServer(String serverId) async {
    developer.log('Saving selected server ID: $serverId', name: 'SecureStorageService');
    await _storage.write(key: _selectedServerKey, value: serverId);
  }

  Future<String?> getSelectedServer() async {
    final selectedId = await _storage.read(key: _selectedServerKey);
    developer.log('Retrieved selected server ID: $selectedId', name: 'SecureStorageService');
    return selectedId;
  }

  Future<void> clearAllData() async {
    await _storage.deleteAll();
  }

  Future<void> removeServer(String serverId) async {
    await _storage.delete(key: _serverPasswordKey(serverId));
    await _storage.delete(key: _serverApiTokenKey(serverId));
    await _storage.delete(key: _serverSelectedTagsKey(serverId));
  }
}