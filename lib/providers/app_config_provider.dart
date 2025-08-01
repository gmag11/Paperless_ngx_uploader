import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/tag.dart';

class AppConfigProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _tagStorageKey = 'selected_tags';
  
  String? _serverUrl;
  String? _username;
  String? _password;
  bool _isConfigured = false;
  bool _isConnecting = false;
  String? _connectionError;
  bool _isConnected = false;
  List<Tag> _selectedTags = [];

  String? get serverUrl => _serverUrl;
  String? get username => _username;
  String? get password => _password;
  bool get isConfigured => _isConfigured;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  bool get isConnected => _isConnected;
  List<Tag> get selectedTags => List.unmodifiable(_selectedTags);

  Future<void> loadConfiguration() async {
    _serverUrl = await _storage.read(key: 'server_url');
    _username = await _storage.read(key: 'username');
    _password = await _storage.read(key: 'password');
    _isConfigured = _serverUrl != null && _username != null && _password != null;
    
    await loadStoredTags();
    notifyListeners();
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
    _isConfigured = true;
    _connectionError = null;
    notifyListeners();
  }

  Future<void> testConnection() async {
    _isConnecting = true;
    _connectionError = null;
    notifyListeners();

    try {
      // TODO: Implement actual connection test
      await Future.delayed(const Duration(seconds: 1));
      _isConnected = true;
    } catch (e) {
      _connectionError = e.toString();
      _isConnected = false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> clearConfiguration() async {
    await _storage.delete(key: 'server_url');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'password');
    
    _serverUrl = null;
    _username = null;
    _password = null;
    _isConfigured = false;
    _isConnected = false;
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