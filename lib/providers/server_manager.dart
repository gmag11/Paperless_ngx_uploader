import 'package:flutter/foundation.dart';
import '../models/server_config.dart';
import '../services/secure_storage_service.dart';
import 'dart:developer' as developer;

class ServerManager extends ChangeNotifier {
  final SecureStorageService _storageService = SecureStorageService();
  final List<ServerConfig> _servers = [];
  ServerConfig? _selectedServer;

  List<ServerConfig> get servers => List.unmodifiable(_servers);
  ServerConfig? get selectedServer => _selectedServer;

  ServerManager() {
    _loadServers();
  }

  Future<void> _loadServers() async {
    try {
      final serversData = await _storageService.getServers();
      _servers.clear();
      
      for (final serverData in serversData) {
        try {
          final server = ServerConfig.fromJson(serverData);
          _servers.add(server);
        } catch (e) {
          developer.log('Error loading server config: $e', name: 'ServerManager');
        }
      }

      final selectedServerId = await _storageService.getSelectedServer();
      if (selectedServerId != null) {
        try {
          _selectedServer = _servers.firstWhere(
            (s) => s.id == selectedServerId,
          );
        } catch (e) {
          if (_servers.isNotEmpty) {
            _selectedServer = _servers.first;
            await _storageService.saveSelectedServer(_selectedServer!.id);
          }
        }
      } else if (_servers.isNotEmpty) {
        _selectedServer = _servers.first;
        await _storageService.saveSelectedServer(_selectedServer!.id);
      }

      // Migration is now handled in main.dart, not here

      notifyListeners();
    } catch (e) {
      developer.log('Error loading servers: $e', name: 'ServerManager');
    }
  }

  // Migration is now handled in main.dart via LegacyMigrationService

  Future<void> refresh() async {
    await _loadServers();
  }

  Future<void> addServer(ServerConfig server) async {
    if (_servers.any((s) => s.id == server.id)) {
      await updateServer(server);
      return;
    }

    _servers.add(server);
    await _saveServers();
    notifyListeners();
  }

  Future<void> updateServer(ServerConfig server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index != -1) {
      _servers[index] = server;
      await _saveServers();
      
      if (_selectedServer?.id == server.id) {
        _selectedServer = server;
      }
      
      notifyListeners();
    }
  }

  Future<void> removeServer(String serverId) async {
    _servers.removeWhere((s) => s.id == serverId);
    
    if (_selectedServer?.id == serverId) {
      _selectedServer = _servers.isNotEmpty ? _servers.first : null;
      if (_selectedServer != null) {
        await _storageService.saveSelectedServer(_selectedServer!.id);
      }
    }
    
    await _storageService.removeServer(serverId);
    await _saveServers();
    notifyListeners();
  }

  Future<void> selectServer(String serverId) async {
    try {
      final server = _servers.firstWhere((s) => s.id == serverId);
      _selectedServer = server;
      await _storageService.saveSelectedServer(serverId);
      notifyListeners();
    } catch (e) {
      developer.log('Server not found: $serverId', name: 'ServerManager');
    }
  }

  Future<void> _saveServers() async {
    final serversJson = _servers.map((s) => s.toJson()).toList();
    await _storageService.saveServers(serversJson);
  }

  // Credential management
  Future<void> saveServerCredentials(String serverId, {required String username, required String password}) async {
    await _storageService.saveServerCredentials(serverId, username, password);
  }

  Future<void> saveServerApiToken(String serverId, {required String apiToken}) async {
    await _storageService.saveServerApiToken(serverId, apiToken);
  }

  Future<String?> getServerPassword(String serverId) async {
    return await _storageService.getServerCredentials(serverId);
  }

  Future<String?> getServerApiToken(String serverId) async {
    return await _storageService.getServerApiToken(serverId);
  }

  Future<Map<String, String?>> getServerCredentials(String serverId) async {
    final password = await _storageService.getServerCredentials(serverId);
    final apiToken = await _storageService.getServerApiToken(serverId);
    
    return {
      'password': password,
      'apiToken': apiToken,
    };
  }

  ServerConfig? getServer(String serverId) {
    try {
      return _servers.firstWhere((s) => s.id == serverId);
    } catch (e) {
      return null;
    }
  }

  // Default tags management - now using server configuration
  @Deprecated('Use ServerConfig.defaultTagIds instead of separate tag storage')
  Future<void> saveServerDefaultTags(String serverId, List<int> tagIds) async {
    // This method is deprecated - use updateServer() to update defaultTagIds instead
    await _storageService.saveServerSelectedTags(serverId, tagIds);
  }

  @Deprecated('Use ServerConfig.defaultTagIds instead of separate tag storage')
  Future<List<int>> getServerDefaultTags(String serverId) async {
    // This method is deprecated - use server.defaultTagIds instead
    return await _storageService.getServerSelectedTags(serverId);
  }
}