import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfigProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  
  String? _serverUrl;
  String? _username;
  String? _password;
  bool _isConfigured = false;
  bool _isConnecting = false;
  String? _connectionError;
  bool _isConnected = false;

  String? get serverUrl => _serverUrl;
  String? get username => _username;
  String? get password => _password;
  bool get isConfigured => _isConfigured;
  bool get isConnecting => _isConnecting;
  String? get connectionError => _connectionError;
  bool get isConnected => _isConnected;

  Future<void> loadConfiguration() async {
    _serverUrl = await _storage.read(key: 'server_url');
    _username = await _storage.read(key: 'username');
    _password = await _storage.read(key: 'password');
    _isConfigured = _serverUrl != null && _username != null && _password != null;
    notifyListeners();
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
}