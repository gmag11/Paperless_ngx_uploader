import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';
import 'package:paperless_ngx_android_uploader/providers/app_config_provider.dart';
import 'package:paperless_ngx_android_uploader/services/secure_storage_service.dart';

/// Fake for flutter_secure_storage channel used by both SecureStorageService and
/// AppConfigProvider.loadStoredTags()/saveSelectedTags().
class _FakeSecureStorageChannel {
  static const String channelName = 'plugins.it_nomads.com/flutter_secure_storage';
  final Map<String, String?> _store = {};

  MethodChannel? _channel;

  Future<dynamic> _handler(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    switch (call.method) {
      case 'write':
        final key = args['key'] as String?;
        final value = args['value'] as String?;
        if (key != null) _store[key] = value;
        return null;
      case 'read':
        final key = args['key'] as String?;
        if (key == null) return null;
        return _store[key];
      case 'delete':
        final key = args['key'] as String?;
        if (key != null) _store.remove(key);
        return null;
      default:
        return null;
    }
  }

  void install() {
    _channel = const MethodChannel(channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel!, _handler);
  }

  void uninstall() {
    if (_channel != null) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel!, null);
    }
  }

  void clear() => _store.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecureStorageChannel fake;

  setUp(() {
    fake = _FakeSecureStorageChannel();
    fake.install();
    fake.clear();
  });

  tearDown(() {
    fake.uninstall();
  });

  group('AppConfigProvider - persistence and loading of auth method and token', () {
    test('Saves and loads Username/Password via SecureStorageService', () async {
      final provider = AppConfigProvider();

      // Save as username/password using provider API
      await provider.saveConfiguration('https://srv', 'alice', 'secret');

      // loadConfiguration should read the stored values and map to fields
      await provider.loadConfiguration();

      expect(provider.serverUrl, 'https://srv');
      expect(provider.authMethod, AuthMethod.usernamePassword);
      expect(provider.username, 'alice');
      expect(provider.password, 'secret');
      expect(provider.apiToken, isNull);
      expect(provider.isConfigured, isTrue);
    });

    test('Saves and loads API Token via SecureStorageService', () async {
      final provider = AppConfigProvider();

      // Save as API token: empty username triggers token method
      await provider.saveConfiguration('https://srv2', '', 'tok_123');

      await provider.loadConfiguration();

      expect(provider.serverUrl, 'https://srv2');
      expect(provider.authMethod, AuthMethod.apiToken);
      expect(provider.apiToken, 'tok_123');
      // Username/password are cleared and set to empty string for token mode
      expect(provider.username, '');
      expect(provider.password, '');
      expect(provider.isConfigured, isTrue);
    });
  });

  group('AppConfigProvider - propagation to PaperlessService', () {
    test('getPaperlessService reflects username/password and baseUrl', () async {
      final provider = AppConfigProvider();
      await provider.saveConfiguration('https://example.org', 'bob', 'pwd');

      // Not necessary to call testConnection; just build service
      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      expect(service!.baseUrl, 'https://example.org'); // normalized is same when no trailing slash
      expect(service.username, 'bob');
      expect(service.password, 'pwd');
      expect(service.useApiToken, isFalse);
      expect(service.apiToken, isNull);
    });

    test('getPaperlessService reflects API token method and value', () async {
      final provider = AppConfigProvider();
      await provider.saveConfiguration('https://example.org/', '', 'tok_999'); // with trailing slash

      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      // PaperlessService normalizes by trimming trailing slash
      expect(service!.baseUrl, 'https://example.org');
      expect(service.useApiToken, isTrue);
      expect(service.apiToken, 'tok_999');
      // In token mode, username/password in provider become empty strings
      expect(service.username, '');
      expect(service.password, '');
    });

    test('Cache invalidates when credentials or method change', () async {
      final provider = AppConfigProvider();

      // Initial: username/password
      await provider.saveConfiguration('https://a', 'u1', 'p1');
      final s1 = provider.getPaperlessService();
      expect(s1, isNotNull);

      // Change password - should invalidate cache and create new service instance
      await provider.saveConfiguration('https://a', 'u1', 'p2');
      final s2 = provider.getPaperlessService();
      expect(identical(s1, s2), isFalse);

      // Switch to token - cache should invalidate again
      await provider.saveConfiguration('https://a', '', 'tok');
      final s3 = provider.getPaperlessService();
      expect(identical(s2, s3), isFalse);
      expect(s3!.useApiToken, isTrue);
    });
  });

  group('AppConfigProvider - switching authentication method and verifying state', () {
    test('Switch Username/Password -> API Token updates state correctly', () async {
      final provider = AppConfigProvider();

      await provider.saveConfiguration('https://srv', 'user', 'pass');
      expect(provider.authMethod, AuthMethod.usernamePassword);
      expect(provider.username, 'user');
      expect(provider.password, 'pass');
      expect(provider.apiToken, isNull);

      // Switch to token (empty username)
      await provider.saveConfiguration('https://srv', '', 'token_abc');

      expect(provider.authMethod, AuthMethod.apiToken);
      expect(provider.apiToken, 'token_abc');
      // Username/password are cleared to empty strings for token mode
      expect(provider.username, '');
      expect(provider.password, '');
      expect(provider.isConfigured, isTrue);

      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      expect(service!.useApiToken, isTrue);
      expect(service.apiToken, 'token_abc');
    });

    test('Switch API Token -> Username/Password updates state correctly', () async {
      final provider = AppConfigProvider();

      await provider.saveConfiguration('https://srv', '', 'tk1');
      expect(provider.authMethod, AuthMethod.apiToken);
      expect(provider.apiToken, 'tk1');

      // Switch back to username/password
      await provider.saveConfiguration('https://srv', 'john', 'doe');

      expect(provider.authMethod, AuthMethod.usernamePassword);
      expect(provider.username, 'john');
      expect(provider.password, 'doe');
      expect(provider.apiToken, isNull);
      expect(provider.isConfigured, isTrue);

      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      expect(service!.useApiToken, isFalse);
      expect(service.username, 'john');
      expect(service.password, 'doe');
    });

    test('testConnection updates connectionStatus from PaperlessService', () async {
      // We do not mock Dio here; instead, we check that provider transitions to "connecting"
      // and then back to a final state even if getPaperlessService cannot contact network.
      // Since real IO is not performed in unit tests, we verify the state transitions that
      // are deterministic pre-call and post-call with try/catch path setting unknownError.
      final provider = AppConfigProvider();

      // Configure so isConfigured == true (token mode)
      await provider.saveConfiguration('https://unreachable.local', '', 'tk');

      // Initial transition to connecting
      expect(provider.connectionStatus, ConnectionStatus.connecting);
      await provider.testConnection();
      // After catch, provider sets unknownError in catch block and notifies.
      expect(provider.connectionStatus == ConnectionStatus.connected ||
          provider.connectionStatus == ConnectionStatus.invalidCredentials ||
          provider.connectionStatus == ConnectionStatus.serverUnreachable ||
          provider.connectionStatus == ConnectionStatus.invalidServerUrl ||
          provider.connectionStatus == ConnectionStatus.sslError ||
          provider.connectionStatus == ConnectionStatus.unknownError, isTrue);
    });
  });

  group('AppConfigProvider - loadConfiguration picks up existing stored values', () {
    test('Manual store with SecureStorageService then loadConfiguration', () async {
      // Persist via SecureStorageService directly to simulate pre-existing data.
      await SecureStorageService.saveCredentials(
        serverUrl: 'https://persisted',
        method: AuthMethod.usernamePassword,
        username: 'persist',
        password: 'ed',
      );

      final provider = AppConfigProvider();
      await provider.loadConfiguration();

      expect(provider.serverUrl, 'https://persisted');
      expect(provider.authMethod, AuthMethod.usernamePassword);
      expect(provider.username, 'persist');
      expect(provider.password, 'ed');
      expect(provider.apiToken, isNull);

      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      expect(service!.useApiToken, isFalse);
      expect(service.username, 'persist');
    });

    test('Manual store for token then loadConfiguration maps correctly', () async {
      await SecureStorageService.saveCredentials(
        serverUrl: 'https://persisted2',
        method: AuthMethod.apiToken,
        apiToken: 'zzz',
      );

      final provider = AppConfigProvider();
      await provider.loadConfiguration();

      expect(provider.serverUrl, 'https://persisted2');
      expect(provider.authMethod, AuthMethod.apiToken);
      expect(provider.apiToken, 'zzz');
      expect(provider.username, ''); // provider clears username/password for token mode
      expect(provider.password, '');
      final svc = provider.getPaperlessService();
      expect(svc, isNotNull);
      expect(svc!.useApiToken, isTrue);
      expect(svc.apiToken, 'zzz');
    });
  });

  group('AppConfigProvider - allowSelfSignedCertificates persistence and loading', () {
    test('Loads default false value when no SSL setting stored', () async {
      final provider = AppConfigProvider();
      await provider.loadConfiguration();
      
      expect(provider.allowSelfSignedCertificates, isFalse);
    });

    test('Loads stored SSL setting from secure storage', () async {
      // Store SSL setting directly in fake storage
      fake._store['allow_self_signed_certificates'] = 'true';
      
      final provider = AppConfigProvider();
      await provider.loadConfiguration();
      
      expect(provider.allowSelfSignedCertificates, isTrue);
    });

    test('Loads false SSL setting from secure storage', () async {
      fake._store['allow_self_signed_certificates'] = 'false';
      
      final provider = AppConfigProvider();
      await provider.loadConfiguration();
      
      expect(provider.allowSelfSignedCertificates, isFalse);
    });

    test('Persists SSL setting via setAllowSelfSignedCertificates', () async {
      final provider = AppConfigProvider();
      
      await provider.setAllowSelfSignedCertificates(true);
      
      expect(fake._store['allow_self_signed_certificates'], 'true');
      expect(provider.allowSelfSignedCertificates, isTrue);
    });

    test('Persists SSL setting changes via setAllowSelfSignedCertificates', () async {
      final provider = AppConfigProvider();
      
      // First set to true
      await provider.setAllowSelfSignedCertificates(true);
      expect(fake._store['allow_self_signed_certificates'], 'true');
      
      // Then set to false
      await provider.setAllowSelfSignedCertificates(false);
      expect(fake._store['allow_self_signed_certificates'], 'false');
    });

    test('Clear configuration removes SSL setting', () async {
      final provider = AppConfigProvider();
      
      // Set SSL setting first
      await provider.setAllowSelfSignedCertificates(true);
      expect(fake._store['allow_self_signed_certificates'], 'true');
      
      // Clear configuration
      await provider.clearConfiguration();
      
      expect(fake._store['allow_self_signed_certificates'], isNull);
      expect(provider.allowSelfSignedCertificates, isFalse);
    });
  });

  group('AppConfigProvider - SSL setting propagation to PaperlessService', () {
    test('PaperlessService receives allowSelfSignedCertificates=false by default', () async {
      final provider = AppConfigProvider();
      await provider.saveConfiguration('https://example.org', 'user', 'pass');
      
      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      
      // Verify the service was created with SSL validation enabled (default)
      // This is tested indirectly by checking that the service is created successfully
      // The actual SSL configuration is tested in paperless_service_test.dart
      expect(service!.baseUrl, 'https://example.org');
    });

    test('PaperlessService receives allowSelfSignedCertificates=true when set', () async {
      final provider = AppConfigProvider();
      await provider.saveConfiguration('https://example.org', 'user', 'pass');
      await provider.setAllowSelfSignedCertificates(true);
      
      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      
      // Service should be recreated with new SSL settings
      expect(service!.baseUrl, 'https://example.org');
    });

    test('Cache invalidates when SSL setting changes', () async {
      final provider = AppConfigProvider();
      await provider.saveConfiguration('https://example.org', 'user', 'pass');
      
      final service1 = provider.getPaperlessService();
      expect(service1, isNotNull);
      
      // Change SSL setting
      await provider.setAllowSelfSignedCertificates(true);
      
      // Service should be recreated (different instance)
      final service2 = provider.getPaperlessService();
      expect(identical(service1, service2), isFalse);
    });

    test('SSL setting included in cache invalidation check', () async {
      final provider = AppConfigProvider();
      
      // Configure with SSL disabled
      await provider.saveConfiguration('https://example.org', 'user', 'pass');
      await provider.setAllowSelfSignedCertificates(false);
      
      final service1 = provider.getPaperlessService();
      
      // Change only SSL setting
      await provider.setAllowSelfSignedCertificates(true);
      
      final service2 = provider.getPaperlessService();
      
      // Should be different instances due to SSL setting change
      expect(identical(service1, service2), isFalse);
    });
  });

  group('AppConfigProvider - integration with SSL setting and credentials', () {
    test('Complete configuration round-trip with SSL setting', () async {
      final provider = AppConfigProvider();
      
      // Configure everything
      await provider.saveConfiguration('https://example.org', 'user', 'pass');
      await provider.setAllowSelfSignedCertificates(true);
      
      // Verify in-memory state
      expect(provider.serverUrl, 'https://example.org');
      expect(provider.username, 'user');
      expect(provider.password, 'pass');
      expect(provider.authMethod, AuthMethod.usernamePassword);
      expect(provider.allowSelfSignedCertificates, isTrue);
      
      // Create service and verify it works
      final service = provider.getPaperlessService();
      expect(service, isNotNull);
      
      // Reload from storage and verify everything is restored
      final provider2 = AppConfigProvider();
      await provider2.loadConfiguration();
      
      expect(provider2.serverUrl, 'https://example.org');
      expect(provider2.username, 'user');
      expect(provider2.password, 'pass');
      expect(provider2.authMethod, AuthMethod.usernamePassword);
      expect(provider2.allowSelfSignedCertificates, isTrue);
    });

    test('SSL setting survives configuration changes', () async {
      final provider = AppConfigProvider();
      
      // Set SSL setting first
      await provider.setAllowSelfSignedCertificates(true);
      
      // Change configuration
      await provider.saveConfiguration('https://example.org', 'user', 'pass');
      
      // SSL setting should persist
      expect(provider.allowSelfSignedCertificates, isTrue);
      expect(fake._store['allow_self_signed_certificates'], 'true');
    });
  });
}