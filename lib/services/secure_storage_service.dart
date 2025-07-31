import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _serverUrlKey = 'server_url';
  static const _usernameKey = 'username';
  static const _passwordKey = 'password';

  static Future<void> saveCredentials({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _serverUrlKey, value: serverUrl);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
  }

  static Future<Map<String, String?>> getCredentials() async {
    final serverUrl = await _storage.read(key: _serverUrlKey);
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);

    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
    };
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _serverUrlKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }

  static Future<bool> hasCredentials() async {
    final credentials = await getCredentials();
    return credentials['serverUrl'] != null &&
           credentials['username'] != null &&
           credentials['password'] != null;
  }
}