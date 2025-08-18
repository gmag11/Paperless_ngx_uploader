import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/server_config.dart';
import '../models/tag.dart';
import 'dart:developer' as developer;

/// Service to migrate legacy single-server configuration to new multi-server format
class LegacyMigrationService {
static const _legacyStorage = FlutterSecureStorage();

// Legacy keys from the old single-server setup - matching the actual legacy app
static const _legacyServerUrlKey = 'server_url';
static const _legacyAuthMethodKey = 'auth_method';
static const _legacyUsernameKey = 'username';
static const _legacyPasswordKey = 'password';
static const _legacyApiTokenKey = 'api_token';
static const _legacyAllowSelfSignedKey = 'allow_self_signed_certificates';
static const _legacySelectedTagsKey = 'selected_tags';

// Cache for legacy configuration to avoid multiple reads
static Map<String, dynamic>? _legacyConfigCache;

  /// Check if legacy configuration exists
  static Future<bool> hasLegacyConfiguration() async {
    try {
      // Use cached configuration if available
      if (_legacyConfigCache != null) {
        final config = _legacyConfigCache!;
        return config['serverUrl'] != null && config['serverUrl']!.isNotEmpty;
      }
      
      final serverUrl = await _legacyStorage.read(key: _legacyServerUrlKey);
      final authMethod = await _legacyStorage.read(key: _legacyAuthMethodKey);
      
      // Check if we have the minimum required configuration
      return serverUrl != null && serverUrl.isNotEmpty && authMethod != null;
    } catch (e) {
      developer.log('Error checking legacy configuration: $e', name: 'LegacyMigrationService');
      return false;
    }
  }

  /// Get all legacy configuration data
  static Future<Map<String, dynamic>> getLegacyConfiguration() async {
    // Return cached configuration if available
    if (_legacyConfigCache != null) {
      developer.log('Using cached legacy configuration', name: 'LegacyMigrationService');
      return _legacyConfigCache!;
    }
    
    try {
      final serverUrl = await _legacyStorage.read(key: _legacyServerUrlKey);
      final authMethodStr = await _legacyStorage.read(key: _legacyAuthMethodKey);
      final username = await _legacyStorage.read(key: _legacyUsernameKey);
      final password = await _legacyStorage.read(key: _legacyPasswordKey);
      final apiToken = await _legacyStorage.read(key: _legacyApiTokenKey);
      final allowSelfSigned = await _legacyStorage.read(key: _legacyAllowSelfSignedKey);
      final selectedTagsJson = await _legacyStorage.read(key: _legacySelectedTagsKey);

      developer.log('Legacy config read - serverUrl: ${serverUrl != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Legacy config read - authMethod: ${authMethodStr != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Legacy config read - username: ${username != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Legacy config read - password: ${password != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Legacy config read - apiToken: ${apiToken != null ? "present (length: ${apiToken.length})" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Legacy config read - allowSelfSigned: ${allowSelfSigned != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Legacy config read - selectedTagsJson: ${selectedTagsJson != null ? "present" : "missing"}', name: 'LegacyMigrationService');

      // Parse authentication method
      AuthMethod authMethod = AuthMethod.usernamePassword;
      if (authMethodStr != null) {
        try {
          authMethod = AuthMethod.values.firstWhere(
            (m) => m.name == authMethodStr,
            orElse: () => AuthMethod.usernamePassword,
          );
        } catch (e) {
          // Fallback: determine from available credentials
          if (apiToken != null && apiToken.isNotEmpty && (username == null || username.isEmpty)) {
            authMethod = AuthMethod.apiToken;
          }
        }
      }

      // Parse SSL certificate setting
      bool sslEnabled = false;
      if (allowSelfSigned != null) {
        sslEnabled = allowSelfSigned.toLowerCase() == 'true';
      }

      // Parse selected tags
      List<int> selectedTagIds = [];
      if (selectedTagsJson != null && selectedTagsJson.isNotEmpty) {
        try {
          final List<dynamic> tagList = jsonDecode(selectedTagsJson) as List<dynamic>;
          for (final tagData in tagList) {
            if (tagData is Map<String, dynamic>) {
              // New format: full tag objects
              final tag = Tag.fromJson(tagData);
              selectedTagIds.add(tag.id);
            } else if (tagData is int) {
              // Legacy format: just tag IDs
              selectedTagIds.add(tagData);
            }
          }
        } catch (e) {
          developer.log('Error parsing legacy tags: $e', name: 'LegacyMigrationService');
        }
      }

      // Cache the configuration for subsequent calls
      _legacyConfigCache = {
        'serverUrl': serverUrl ?? '',
        'authMethod': authMethod.name, // Convert enum to string
        'username': username,
        'password': password,
        'apiToken': apiToken,
        'allowSelfSignedCertificates': sslEnabled,
        'selectedTagIds': selectedTagIds,
      };
      
      return _legacyConfigCache!;
    } catch (e) {
      developer.log('Error getting legacy configuration: $e', name: 'LegacyMigrationService');
      rethrow;
    }
  }

  /// Migrate legacy configuration to new multi-server format
  static Future<ServerConfig?> migrateLegacyConfiguration() async {
    try {
      if (!await hasLegacyConfiguration()) {
        developer.log('No legacy configuration found', name: 'LegacyMigrationService');
        return null;
      }

      final legacyConfig = await getLegacyConfiguration();
      
      // Validate minimum required data
      if (legacyConfig['serverUrl'] == null || legacyConfig['serverUrl'].isEmpty) {
        throw Exception('Server URL is required for migration');
      }

      // Determine authentication method and credentials
      final authMethodStr = legacyConfig['authMethod'] as String;
      final username = legacyConfig['username'] as String?;
      final password = legacyConfig['password'] as String?;
      final apiToken = legacyConfig['apiToken'] as String?;
      final sslEnabled = legacyConfig['allowSelfSignedCertificates'] as bool;

      // More robust auth method determination
      AuthMethod authMethod;
      
      // First, try to use the stored auth method
      try {
        authMethod = AuthMethod.values.firstWhere(
          (method) => method.name == authMethodStr,
          orElse: () => AuthMethod.usernamePassword,
        );
      } catch (e) {
        authMethod = AuthMethod.usernamePassword;
      }
      
      // Override based on available credentials if the stored method doesn't make sense
      if (apiToken != null && apiToken.isNotEmpty && (username == null || username.isEmpty)) {
        authMethod = AuthMethod.apiToken;
        developer.log('Overriding auth method to API token based on available credentials', name: 'LegacyMigrationService');
      } else if (username != null && username.isNotEmpty && password != null && password.isNotEmpty && (apiToken == null || apiToken.isEmpty)) {
        authMethod = AuthMethod.usernamePassword;
        developer.log('Overriding auth method to username/password based on available credentials', name: 'LegacyMigrationService');
      }

      developer.log('Migrating config - apiToken: ${apiToken != null ? "present (length: ${apiToken.length})" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Migrating config - username: ${username != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Migrating config - password: ${password != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Migrating config - authMethod: $authMethod', name: 'LegacyMigrationService');

      // Validate credentials based on determined auth method
      if (authMethod == AuthMethod.apiToken) {
        if (apiToken == null || apiToken.isEmpty) {
          throw Exception('API token is required for API token authentication');
        }
      } else if (authMethod == AuthMethod.usernamePassword) {
        if (username == null || username.isEmpty || password == null || password.isEmpty) {
          throw Exception('Username and password are required for username/password authentication');
        }
      }

      // Create new server configuration
      final serverConfig = ServerConfig(
        id: ServerConfig.generateId(),
        name: 'Migrated Server',
        serverUrl: legacyConfig['serverUrl'],
        authMethod: authMethod,
        username: authMethod == AuthMethod.usernamePassword ? username : null,
        apiToken: authMethod == AuthMethod.apiToken ? apiToken : null,
        allowSelfSignedCertificates: sslEnabled,
        defaultTagIds: List<int>.from(legacyConfig['selectedTagIds'] as List<int>),
      );

      // Persist sensitive credentials into secure storage so the UI (ConfigDialog)
      // can load them immediately after migration without requiring user input.
      try {
        if (authMethod == AuthMethod.apiToken && apiToken != null && apiToken.isNotEmpty) {
          await _legacyStorage.write(key: 'server_${serverConfig.id}_api_token', value: apiToken);
          developer.log('Saved migrated api token to secure storage for server ${serverConfig.id}', name: 'LegacyMigrationService');
        } else if (authMethod == AuthMethod.usernamePassword && password != null && password.isNotEmpty) {
          // Note: username is already stored in serverConfig; store the password securely
          await _legacyStorage.write(key: 'server_${serverConfig.id}_password', value: password);
          developer.log('Saved migrated password to secure storage for server ${serverConfig.id}', name: 'LegacyMigrationService');
        }
      } catch (e) {
        developer.log('Error saving migrated credentials to secure storage: $e', name: 'LegacyMigrationService');
      }

      developer.log('Created server config - apiToken: ${serverConfig.apiToken != null ? "present (length: ${serverConfig.apiToken!.length})" : "missing"}', name: 'LegacyMigrationService');
      developer.log('Created server config - username: ${serverConfig.username != null ? "present" : "missing"}', name: 'LegacyMigrationService');
      return serverConfig;
    } catch (e) {
      developer.log('Error migrating legacy configuration: $e', name: 'LegacyMigrationService');
      rethrow;
    }
  }

  /// Clean up legacy configuration after successful migration
  static Future<void> cleanupLegacyConfiguration() async {
    try {
      await _legacyStorage.delete(key: _legacyServerUrlKey);
      await _legacyStorage.delete(key: _legacyAuthMethodKey);
      await _legacyStorage.delete(key: _legacyUsernameKey);
      await _legacyStorage.delete(key: _legacyPasswordKey);
      await _legacyStorage.delete(key: _legacyApiTokenKey);
      await _legacyStorage.delete(key: _legacyAllowSelfSignedKey);
      await _legacyStorage.delete(key: _legacySelectedTagsKey);
      
      // Clear cache after cleanup
      _legacyConfigCache = null;
      
      developer.log('Legacy configuration cleaned up successfully', name: 'LegacyMigrationService');
    } catch (e) {
      developer.log('Error cleaning up legacy configuration: $e', name: 'LegacyMigrationService');
    }
  }

  /// Get migration summary for debugging/logging
  static Future<Map<String, dynamic>> getMigrationSummary() async {
    try {
      final hasLegacy = await hasLegacyConfiguration();
      if (!hasLegacy) {
        return {'hasLegacy': false};
      }

      final legacyConfig = await getLegacyConfiguration();
      return {
        'hasLegacy': true,
        'serverUrl': legacyConfig['serverUrl'],
        'authMethod': legacyConfig['authMethod'].toString(),
        'hasUsername': legacyConfig['username'] != null,
        'hasPassword': legacyConfig['password'] != null,
        'hasApiToken': legacyConfig['apiToken'] != null,
        'apiTokenLength': legacyConfig['apiToken']?.length ?? 0,
        'allowSelfSignedCertificates': legacyConfig['allowSelfSignedCertificates'],
        'tagCount': (legacyConfig['selectedTagIds'] as List<int>).length,
      };
    } catch (e) {
      return {'hasLegacy': false, 'error': e.toString()};
    }
  }
}