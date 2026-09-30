import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

/// Thrown internally when the secure key/value backend cannot hold a payload
/// and certificate material must use the app-private file fallback instead.
class SecureBackendUnavailable implements Exception {
  const SecureBackendUnavailable();
}

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static SharedPreferences? _fallbackPrefs;
  static bool _keyringFailed = false;

  /// Above this size (in base64 characters) a certificate blob is written to an
  /// app-private file instead of the key/value store.
  static const _inlineBlobLimit = 2048;

  /// Marker prefix for a blob stored in an app-private file.
  static const _filePrefix = 'file:';

  // ---- test seams (null in production) ----
  static Future<String?> Function(String key)? debugKvRead;
  static Future<void> Function(String key, String value)? debugKvWrite;
  static Future<void> Function(String key)? debugKvDelete;
  static Future<Directory> Function()? debugCertificateDirectory;

  /// Label used in log messages to distinguish fallback vs secure storage.
  static String get _backendLabel => _keyringFailed ? 'SharedPreferences (fallback)' : 'SecureStorage';

  /// Returns the fallback [SharedPreferences] instance, initialising it lazily.
  static Future<SharedPreferences?> _getFallbackPrefs() async {
    if (_fallbackPrefs != null) return _fallbackPrefs;
    try {
      _fallbackPrefs = await SharedPreferences.getInstance();
    } catch (e) {
      developer.log('SharedPreferences fallback initialisation failed: $e',
          name: 'SecureStorageService');
    }
    return _fallbackPrefs;
  }

  /// Switches to SharedPreferences fallback when the system keyring is
  /// unavailable on Linux.  On other platforms the exception is rethrown.
  static Future<void> _handleKeyringFailure(Object e) async {
    if (e is PlatformException && e.code == 'KeyringLocked' && Platform.isLinux) {
      if (!_keyringFailed) {
        developer.log(
          'System keyring locked or unavailable – switching to SharedPreferences fallback',
          name: 'SecureStorageService',
        );
        _keyringFailed = true;
      }
      await _getFallbackPrefs();
      return;
    }
    throw e;
  }

  // ---- internal read / write / delete wrappers ----

  Future<String?> _read(String key) async {
    if (_keyringFailed) {
      final prefs = await _getFallbackPrefs();
      return prefs?.getString(key);
    }
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      await _handleKeyringFailure(e);
      final prefs = await _getFallbackPrefs();
      return prefs?.getString(key);
    }
  }

  Future<void> _write(String key, String value) async {
    if (_keyringFailed) {
      final prefs = await _getFallbackPrefs();
      await prefs?.setString(key, value);
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      await _handleKeyringFailure(e);
      final prefs = await _getFallbackPrefs();
      await prefs?.setString(key, value);
    }
  }

  Future<void> _delete(String key) async {
    if (_keyringFailed) {
      final prefs = await _getFallbackPrefs();
      await prefs?.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (e) {
      await _handleKeyringFailure(e);
      final prefs = await _getFallbackPrefs();
      await prefs?.remove(key);
    }
  }

  Future<void> _deleteAll() async {
    if (_keyringFailed) {
      final prefs = await _getFallbackPrefs();
      await prefs?.clear();
      return;
    }
    try {
      await _storage.deleteAll();
    } on PlatformException catch (e) {
      await _handleKeyringFailure(e);
      final prefs = await _getFallbackPrefs();
      await prefs?.clear();
    }
  }

  // ---- keys ----

  static String _serverPasswordKey(String serverId) => 'server_${serverId}_password';
  static String _serverApiTokenKey(String serverId) => 'server_${serverId}_api_token';
  static String _serverClientCertificateKey(String serverId) => 'server_${serverId}_client_cert';
  static String _serverClientPrivateKeyKey(String serverId) => 'server_${serverId}_client_key';
  static String _serverClientCertificatePasswordKey(String serverId) => 'server_${serverId}_client_cert_password';
  static String _serverCustomCaKey(String serverId) => 'server_${serverId}_custom_ca';
  static String _serverSelectedTagsKey(String serverId) => 'server_${serverId}_selected_tags';
  static String _serverFavoriteTagsKey(String serverId) => 'server_${serverId}_favorite_tags';

  static const _serversKey = 'servers';
  static const _selectedServerKey = 'selected_server_id';

  // ---- public API (unchanged signatures) ----

  Future<void> saveServerCredentials(String serverId, String username, String password) async {
    await _write(_serverPasswordKey(serverId), password);
  }

  Future<void> saveServerApiToken(String serverId, String apiToken) async {
    await _write(_serverApiTokenKey(serverId), apiToken);
  }

  Future<String?> getServerCredentials(String serverId) async {
    return await _read(_serverPasswordKey(serverId));
  }

  Future<String?> getServerApiToken(String serverId) async {
    return await _read(_serverApiTokenKey(serverId));
  }

  // ---- Client certificate (mutual TLS) material ----

  Future<void> saveServerClientCertificate(String serverId, List<int> bytes) async {
    await _writeBlob(_serverClientCertificateKey(serverId), bytes);
  }

  Future<List<int>?> getServerClientCertificate(String serverId) async {
    return await _readBlob(_serverClientCertificateKey(serverId));
  }

  Future<void> saveServerClientPrivateKey(String serverId, List<int> bytes) async {
    await _writeBlob(_serverClientPrivateKeyKey(serverId), bytes);
  }

  Future<List<int>?> getServerClientPrivateKey(String serverId) async {
    return await _readBlob(_serverClientPrivateKeyKey(serverId));
  }

  Future<void> saveServerClientCertificatePassword(String serverId, String password) async {
    await _kvWrite(_serverClientCertificatePasswordKey(serverId), password);
  }

  Future<String?> getServerClientCertificatePassword(String serverId) async {
    return await _kvRead(_serverClientCertificatePasswordKey(serverId));
  }

  Future<void> saveServerCustomCa(String serverId, List<int> bytes) async {
    await _writeBlob(_serverCustomCaKey(serverId), bytes);
  }

  Future<List<int>?> getServerCustomCa(String serverId) async {
    return await _readBlob(_serverCustomCaKey(serverId));
  }

  Future<void> deleteServerClientCertificate(String serverId) async {
    await _deleteBlob(_serverClientCertificateKey(serverId));
  }

  Future<void> deleteServerClientPrivateKey(String serverId) async {
    await _deleteBlob(_serverClientPrivateKeyKey(serverId));
  }

  Future<void> deleteServerClientCertificatePassword(String serverId) async {
    await _kvDelete(_serverClientCertificatePasswordKey(serverId));
  }

  Future<void> deleteServerCustomCa(String serverId) async {
    await _deleteBlob(_serverCustomCaKey(serverId));
  }

  /// Deletes all client-certificate and custom-CA material for a server.
  Future<void> removeServerClientCertificateData(String serverId) async {
    await deleteServerClientCertificate(serverId);
    await deleteServerClientPrivateKey(serverId);
    await deleteServerClientCertificatePassword(serverId);
    await deleteServerCustomCa(serverId);
  }

  // ---- secret blob helpers ----

  Future<String?> _kvRead(String key) async {
    final override = debugKvRead;
    return override != null ? override(key) : _read(key);
  }

  Future<void> _kvWrite(String key, String value) async {
    final override = debugKvWrite;
    if (override != null) {
      await override(key, value);
      return;
    }
    await _write(key, value);
  }

  Future<void> _kvDelete(String key) async {
    final override = debugKvDelete;
    if (override != null) {
      await override(key);
      return;
    }
    await _delete(key);
  }

  /// Writes certificate material without ever using the plaintext preferences
  /// fallback: if the secure backend is unavailable the caller falls back to an
  /// app-private file instead.
  Future<void> _writeSecureValue(String key, String value) async {
    final override = debugKvWrite;
    if (override != null) {
      await override(key, value);
      return;
    }
    if (_keyringFailed) {
      throw const SecureBackendUnavailable();
    }
    await _storage.write(key: key, value: value);
  }

  Future<Directory> _certificateDirectory() async {
    final override = debugCertificateDirectory;
    if (override != null) return override();
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/certificates');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _blobFileName(String key) =>
      '${key.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}.bin';

  Future<void> _writeBlob(String key, List<int> bytes) async {
    final encoded = base64Encode(bytes);
    if (encoded.length <= _inlineBlobLimit) {
      try {
        await _writeSecureValue(key, encoded);
        return;
      } on PlatformException catch (e) {
        if (e.code == 'KeyringLocked' && Platform.isLinux) {
          _keyringFailed = true;
        }
      } on SecureBackendUnavailable {
        // Fall through to the file fallback.
      } catch (e) {
        developer.log(
            'Secure backend rejected certificate payload (${e.runtimeType})',
            name: 'SecureStorageService');
      }
    }
    final dir = await _certificateDirectory();
    final file = File('${dir.path}/${_blobFileName(key)}');
    await file.writeAsBytes(bytes, flush: true);
    // The reference is not secret, so the normal storage path is fine.
    await _kvWrite(key, '$_filePrefix${file.path}');
  }

  Future<List<int>?> _readBlob(String key) async {
    final value = await _kvRead(key);
    if (value == null) return null;
    if (value.startsWith(_filePrefix)) {
      final file = File(value.substring(_filePrefix.length));
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    }
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteBlob(String key) async {
    final value = await _kvRead(key);
    if (value != null && value.startsWith(_filePrefix)) {
      final file = File(value.substring(_filePrefix.length));
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _kvDelete(key);
  }

  @Deprecated('Use ServerConfig.defaultTagIds instead of separate tag storage')
  Future<void> saveServerSelectedTags(String serverId, List<int> tagIds) async {
    await _write(_serverSelectedTagsKey(serverId), jsonEncode(tagIds));
  }

  @Deprecated('Use ServerConfig.defaultTagIds instead of separate tag storage')
  Future<List<int>> getServerSelectedTags(String serverId) async {
    final tagsJson = await _read(_serverSelectedTagsKey(serverId));
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
    await _delete(_serverSelectedTagsKey(serverId));
  }

  // Favorite tags — persisted independently from ServerConfig for reliability
  Future<void> saveFavoriteTags(String serverId, List<int> tagIds) async {
    await _write(_serverFavoriteTagsKey(serverId), jsonEncode(tagIds));
  }

  Future<List<int>> getFavoriteTags(String serverId) async {
    final json = await _read(_serverFavoriteTagsKey(serverId));
    if (json == null) return [];
    try {
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      return list.map((id) => id as int).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveServers(List<Map<String, dynamic>> servers) async {
    developer.log('Saving ${servers.length} servers to $_backendLabel', name: 'SecureStorageService');
    await _write(_serversKey, jsonEncode(servers));
    developer.log('Servers saved successfully', name: 'SecureStorageService');
  }

  Future<List<Map<String, dynamic>>> getServers() async {
    final serversJson = await _read(_serversKey);
    if (serversJson == null) {
      developer.log('No servers found in $_backendLabel', name: 'SecureStorageService');
      return [];
    }

    try {
      final List<dynamic> serversList = jsonDecode(serversJson) as List<dynamic>;
      final servers = serversList.map((server) => Map<String, dynamic>.from(server as Map<String, dynamic>)).toList();
      developer.log('Loaded ${servers.length} servers from $_backendLabel', name: 'SecureStorageService');
      return servers;
    } catch (e) {
      developer.log('Error loading servers: $e', name: 'SecureStorageService');
      return [];
    }
  }

  Future<void> saveSelectedServer(String serverId) async {
    developer.log('Saving selected server ID: $serverId to $_backendLabel', name: 'SecureStorageService');
    await _write(_selectedServerKey, serverId);
  }

  Future<String?> getSelectedServer() async {
    final selectedId = await _read(_selectedServerKey);
    developer.log('Retrieved selected server ID: $selectedId from $_backendLabel', name: 'SecureStorageService');
    return selectedId;
  }

  Future<void> clearAllData() async {
    await _deleteAll();
  }

  Future<void> removeServer(String serverId) async {
    await _delete(_serverPasswordKey(serverId));
    await _delete(_serverApiTokenKey(serverId));
    await _delete(_serverSelectedTagsKey(serverId));
    await removeServerClientCertificateData(serverId);
  }
}