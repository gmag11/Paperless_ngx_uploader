import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthMethod {
  usernamePassword,
  apiToken,
}

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Common
  static const _serverUrlKey = 'server_url';
  static const _authMethodKey = 'auth_method';

  // Username/Password keys
  static const _usernameKey = 'username';
  static const _passwordKey = 'password';

  // API Token key
  static const _apiTokenKey = 'api_token';

  // Save credentials based on selected authentication method
  static Future<void> saveCredentials({
    required String serverUrl,
    required AuthMethod method,
    String? username,
    String? password,
    String? apiToken,
  }) async {

    // Persist server and auth method
    await _storage.write(key: _serverUrlKey, value: serverUrl);
    await _storage.write(key: _authMethodKey, value: method.name);

    // Clear all credential variants first to avoid stale data when switching
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _apiTokenKey);

    // Store only what is needed for the chosen method
    switch (method) {
      case AuthMethod.usernamePassword:
        if (username != null) {
          await _storage.write(key: _usernameKey, value: username);
        }
        if (password != null) {
          await _storage.write(key: _passwordKey, value: password);
        }
        break;
      case AuthMethod.apiToken:
        if (apiToken != null) {
          await _storage.write(key: _apiTokenKey, value: apiToken);
        }
        break;
    }
  }

  // Retrieve credentials with awareness of auth method
  static Future<Map<String, String?>> getCredentials() async {
    final serverUrl = await _storage.read(key: _serverUrlKey);
    final authMethodStr = await _storage.read(key: _authMethodKey);

    AuthMethod? method;
    if (authMethodStr != null) {
      try {
        method = AuthMethod.values.firstWhere((m) => m.name == authMethodStr);
      } catch (e) {
        method = null;
      }
    }

    String? username;
    String? password;
    String? apiToken;

    if (method == AuthMethod.apiToken) {
      apiToken = await _storage.read(key: _apiTokenKey);
    } else if (method == AuthMethod.usernamePassword) {
      username = await _storage.read(key: _usernameKey);
      password = await _storage.read(key: _passwordKey);
    } else {
      // Fallback: attempt to infer from existing keys for backward compatibility
      username = await _storage.read(key: _usernameKey);
      password = await _storage.read(key: _passwordKey);
      apiToken = await _storage.read(key: _apiTokenKey);
      if (apiToken != null && (username == null || password == null)) {
        method = AuthMethod.apiToken;
      } else if (username != null || password != null) {
        method = AuthMethod.usernamePassword;
      }
    }

    final result = {
      'serverUrl': serverUrl,
      'authMethod': method?.name,
      'username': username,
      'password': password,
      'apiToken': apiToken,
    };
    return result;
  }

  // Clear all credential data regardless of method
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _serverUrlKey);
    await _storage.delete(key: _authMethodKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _apiTokenKey);
  }

  // Check that required pieces for the stored method exist
  static Future<bool> hasCredentials() async {
    final data = await getCredentials();
    final methodName = data['authMethod'];

    final has =
        data['serverUrl'] != null &&
        methodName != null &&
        ((methodName == AuthMethod.usernamePassword.name &&
              data['username'] != null && data['password'] != null) ||
         (methodName == AuthMethod.apiToken.name &&
              data['apiToken'] != null));

    return has;
  }
}