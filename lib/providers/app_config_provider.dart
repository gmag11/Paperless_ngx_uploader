import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/tag.dart';
import '../models/connection_status.dart';
import '../services/paperless_service.dart';

class AppConfigProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _tagStorageKey = 'selected_tags';
  
  String? _serverUrl;
  String? _username;
  String? _password;
  ConnectionStatus _connectionStatus = ConnectionStatus.notConfigured;
  String? _connectionError;
  List<Tag> _selectedTags = [];

  String? get serverUrl => _serverUrl;
  String? get username => _username;
  String? get password => _password;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get connectionError => _connectionError;
  bool get isConfigured => _serverUrl != null &&
                          _username != null &&
                          _password != null;
  bool get isConnecting => _connectionStatus == ConnectionStatus.connecting;
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  List<Tag> get selectedTags => List.unmodifiable(_selectedTags);

  Future<void> loadConfiguration() async {
    _serverUrl = await _storage.read(key: 'server_url');
    _username = await _storage.read(key: 'username');
    _password = await _storage.read(key: 'password');
    
    if (_serverUrl != null && _username != null && _password != null) {
      _connectionStatus = ConnectionStatus.connecting;
      notifyListeners();
      await testConnection();
    } else {
      _connectionStatus = ConnectionStatus.notConfigured;
      notifyListeners();
    }
    
    await loadStoredTags();
  }

  Future<void> loadStoredTags() async {
    final storedTagsJson = await _storage.read(key: _tagStorageKey);
    if (storedTagsJson != null) {
      try {
        final List<dynamic> tagList = jsonDecode(storedTagsJson) as List<dynamic>;
        _selectedTags = tagList.map((tag) => Tag.fromJson(tag)).toList();
      } catch (e) {
        debugPrint('Error loading stored tags: $e');
        _selectedTags = [];
      }
    }
  }

  Future<void> saveSelectedTags() async {
    try {
      final tagListJson = jsonEncode(_selectedTags.map((tag) => tag.toJson()).toList());
      await _storage.write(key: _tagStorageKey, value: tagListJson);
    } catch (e) {
      debugPrint('Error saving tags: $e');
    }
  }

  Future<void> saveConfiguration(String serverUrl, String username, String password) async {
    await _storage.write(key: 'server_url', value: serverUrl);
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'password', value: password);
    
    _serverUrl = serverUrl;
    _username = username;
    _password = password;
    _connectionStatus = ConnectionStatus.connecting;
    _connectionError = null;
    notifyListeners();
  }

  Future<void> testConnection() async {
    if (!isConfigured) {
      _connectionStatus = ConnectionStatus.notConfigured;
      return;
    }

    _connectionStatus = ConnectionStatus.connecting;
    _connectionError = null;
    notifyListeners();

    try {
      final service = PaperlessService(
        baseUrl: _serverUrl!,
        username: _username!,
        password: _password!,
      );

      _connectionStatus = await service.testConnection();
      
      _connectionError = switch (_connectionStatus) {
        ConnectionStatus.connected => null,
        ConnectionStatus.invalidCredentials => 'Invalid username or password',
        ConnectionStatus.serverUnreachable => 'Server is unreachable',
        ConnectionStatus.invalidServerUrl => 'Invalid server URL or not a Paperless-NGX server',
        ConnectionStatus.sslError => 'SSL certificate error',
        ConnectionStatus.unknownError => 'Unknown connection error occurred',
        _ => null
      };
    } catch (e) {
      _connectionStatus = ConnectionStatus.unknownError;
      _connectionError = e.toString();
    }
    
    notifyListeners();
  }

  Future<void> clearConfiguration() async {
    await _storage.delete(key: 'server_url');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'password');
    
    _serverUrl = null;
    _username = null;
    _password = null;
    _connectionStatus = ConnectionStatus.notConfigured;
    _connectionError = null;
    notifyListeners();
  }

  void setSelectedTags(List<Tag> tags) {
    _selectedTags = List.from(tags);
    saveSelectedTags();
    notifyListeners();
  }

  List<Tag> getSelectedTags() {
    return List.unmodifiable(_selectedTags);
  }

  void clearSelectedTags() {
    _selectedTags.clear();
    saveSelectedTags();
    notifyListeners();
  }

  void addSelectedTag(Tag tag) {
    if (!_selectedTags.any((t) => t.id == tag.id)) {
      _selectedTags.add(tag);
      saveSelectedTags();
      notifyListeners();
    }
  }

  void removeSelectedTag(Tag tag) {
    _selectedTags.removeWhere((t) => t.id == tag.id);
    saveSelectedTags();
    notifyListeners();
  }
}