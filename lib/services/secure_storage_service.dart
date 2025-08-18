import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

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

  Future<void> saveServerSelectedTags(String serverId, List<int> tagIds) async {
    final key = _serverSelectedTagsKey(serverId);
    await _storage.write(key: key, value: jsonEncode(tagIds));
  }

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

  Future<void> saveServers(List<Map<String, dynamic>> servers) async {
    await _storage.write(key: _serversKey, value: jsonEncode(servers));
  }

  Future<List<Map<String, dynamic>>> getServers() async {
    final serversJson = await _storage.read(key: _serversKey);
    if (serversJson == null) return [];
    
    try {
      final List<dynamic> serversList = jsonDecode(serversJson) as List<dynamic>;
      return serversList.map((server) => Map<String, dynamic>.from(server as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSelectedServer(String serverId) async {
    await _storage.write(key: _selectedServerKey, value: serverId);
  }

  Future<String?> getSelectedServer() async {
    return await _storage.read(key: _selectedServerKey);
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