import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/tag.dart';
import '../models/connection_status.dart';
import '../services/paperless_service.dart';
import '../services/secure_storage_service.dart';
import 'dart:developer' as developer;

class AppConfigProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _tagStorageKey = 'selected_tags';
  
  String? _serverUrl;
  String? _username;
  String? _password;
  // Auth method/token
  AuthMethod? _authMethod;
  String? _apiToken;
  bool _allowSelfSignedCertificates = false;

  ConnectionStatus _connectionStatus = ConnectionStatus.notConfigured;
  String? _connectionError;
  List<Tag> _selectedTags = [];

  // Cached PaperlessService instance
  PaperlessService? _serviceCache;

  String? get serverUrl => _serverUrl;
  String? get username => _username;
  String? get password => _password;
  AuthMethod? get authMethod => _authMethod;
  String? get apiToken => _apiToken;
  bool get allowSelfSignedCertificates => _allowSelfSignedCertificates;

  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get connectionError => _connectionError;

  bool get isConfigured {
    if (_serverUrl == null || _authMethod == null) return false;
    if (_authMethod == AuthMethod.apiToken) {
      return _apiToken != null && _apiToken!.isNotEmpty;
    }
    return _username != null && _password != null && _username!.isNotEmpty && _password!.isNotEmpty;
  }

  bool get isConnecting => _connectionStatus == ConnectionStatus.connecting;
  bool get isConnected => _connectionStatus == ConnectionStatus.connected;
  List<Tag> get selectedTags => List.unmodifiable(_selectedTags);

  PaperlessService? getPaperlessService() {
    if (!isConfigured) {
      return null;
    }

    final useApi = _authMethod == AuthMethod.apiToken;
    final cacheMismatch =
        _serviceCache == null ||
        _serviceCache!.baseUrl != _serverUrl ||
        _serviceCache!.username != (_username ?? '') ||
        _serviceCache!.password != (_password ?? '') ||
        _serviceCache!.useApiToken != useApi ||
        _serviceCache!.apiToken != (useApi ? _apiToken : null);

    if (cacheMismatch) {
      _serviceCache = PaperlessService(
        baseUrl: _serverUrl!,
        username: _username ?? '',
        password: _password ?? '',
        useApiToken: useApi,
        apiToken: useApi ? _apiToken : null,
        allowSelfSignedCertificates: _allowSelfSignedCertificates,
      );
    }
    return _serviceCache;
  }

  Future<void> loadConfiguration() async {
    // Use SecureStorageService to load full credential set including method/token
    final creds = await SecureStorageService.getCredentials();
    _serverUrl = creds['serverUrl'];
    final methodName = creds['authMethod'];
    _authMethod = methodName != null
        ? AuthMethod.values.firstWhere(
            (m) => m.name == methodName,
            orElse: () => AuthMethod.usernamePassword,
          )
        : null;
  
    if (_authMethod == AuthMethod.apiToken) {
      _apiToken = creds['apiToken'];
      _username = '';
      _password = '';
    } else if (_authMethod == AuthMethod.usernamePassword) {
      _username = creds['username'];
      _password = creds['password'];
      _apiToken = null;
    } else {
      // not configured
      _username = null;
      _password = null;
      _apiToken = null;
    }

    // Load SSL certificate setting
    final sslSetting = await _storage.read(key: 'allow_self_signed_certificates');
    _allowSelfSignedCertificates = sslSetting == 'true';

    // Reset cache on load; will be lazily created
    _serviceCache = null;
    
    _connectionStatus = ConnectionStatus.notConfigured;
    notifyListeners();
    
    await loadStoredTags();
  }

  Future<void> loadStoredTags() async {
    final storedTagsJson = await _storage.read(key: _tagStorageKey);
    if (storedTagsJson != null) {
      try {
        final List<dynamic> tagList = jsonDecode(storedTagsJson) as List<dynamic>;
        _selectedTags = [];
        
        for (final tagData in tagList) {
          try {
            if (tagData is Map<String, dynamic>) {
              final tag = Tag.fromJson(tagData);
              // Only add tags that have valid required fields
              if (tag.id != 0 && tag.name.isNotEmpty && tag.slug.isNotEmpty) {
                _selectedTags.add(tag);
              } else {
                if (kDebugMode) {
                  developer.log('Skipping invalid tag data: missing required fields',
                                name: 'AppConfigProvider.loadStoredTags',
                                error: 'Invalid tag data - $tagData');
                }
              }
            } else {
              if (kDebugMode) {
                developer.log('Skipping invalid tag data: not a map - $tagData',
                              name: 'AppConfigProvider.loadStoredTags');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              developer.log('Error parsing individual tag: $e\nTag data: $tagData',
                            name: 'AppConfigProvider.loadStoredTags',
                            error: e);
            }
            // Continue processing other tags
          }
        }

        if (_selectedTags.isEmpty && tagList.isNotEmpty) {
          if (kDebugMode) {
            developer.log('Warning: No valid tags could be recovered from stored data',
                          name: 'AppConfigProvider.loadStoredTags');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          developer.log('Error decoding stored tags JSON: $e',
                        name: 'AppConfigProvider.loadStoredTags',
                        error: e);
        }
        _selectedTags = [];
      }
    }
    notifyListeners();
  }

  Future<void> saveSelectedTags() async {
    try {
      final tagListJson = jsonEncode(_selectedTags.map((tag) => tag.toJson()).toList());
      await _storage.write(key: _tagStorageKey, value: tagListJson);
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error saving tags: $e',
                      name: 'AppConfigProvider.saveSelectedTags',
                      error: e);
      }
    }
  }

  Future<void> saveConfiguration(String serverUrl, String usernameOrEmpty, String passwordOrToken) async {
    // IMPORTANT: Resolve method from current input first. If username is empty => apiToken.
    // Do not let previous _authMethod override explicit user intent from dialog.
    final AuthMethod method =
        (usernameOrEmpty.isEmpty) ? AuthMethod.apiToken : AuthMethod.usernamePassword;
  
    if (method == AuthMethod.apiToken) {
      await SecureStorageService.saveCredentials(
        serverUrl: serverUrl,
        method: AuthMethod.apiToken,
        apiToken: passwordOrToken,
      );
    } else {
      await SecureStorageService.saveCredentials(
        serverUrl: serverUrl,
        method: AuthMethod.usernamePassword,
        username: usernameOrEmpty,
        password: passwordOrToken,
      );
    }
  
    // If any value changed, update state and invalidate cache
    final prevServer = _serverUrl;
    final prevUser = _username;
    final prevPass = _password;
    final prevMethod = _authMethod;
    final prevToken = _apiToken;
    final prevSsl = _allowSelfSignedCertificates;
  
    _serverUrl = serverUrl;
    _authMethod = method;
    if (method == AuthMethod.apiToken) {
      _apiToken = passwordOrToken;
      _username = '';
      _password = '';
    } else {
      _username = usernameOrEmpty;
      _password = passwordOrToken;
      _apiToken = null;
    }
  
    final changed = prevServer != _serverUrl ||
        prevUser != _username ||
        prevPass != _password ||
        prevMethod != _authMethod ||
        prevToken != _apiToken ||
        prevSsl != _allowSelfSignedCertificates;

    if (changed) {
      _serviceCache = null;
    }
  
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
      final service = getPaperlessService()!;
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
      developer.log('testConnection: exception -> $_connectionError',
          name: 'AppConfigProvider', error: e);
    }
    
    notifyListeners();
  }

  Future<void> clearConfiguration() async {
    await SecureStorageService.clearCredentials();
    await _storage.delete(key: 'allow_self_signed_certificates');
    
    _serverUrl = null;
    _username = null;
    _password = null;
    _authMethod = null;
    _apiToken = null;
    _allowSelfSignedCertificates = false;
  
    // Invalidate cache
    _serviceCache = null;
  
    _connectionStatus = ConnectionStatus.notConfigured;
    _connectionError = null;
    notifyListeners();
  }

  Future<void> setAllowSelfSignedCertificates(bool allow) async {
    _allowSelfSignedCertificates = allow;
    await _storage.write(
      key: 'allow_self_signed_certificates',
      value: allow.toString(),
    );
    // Invalidate cache to recreate service with new SSL settings
    _serviceCache = null;
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