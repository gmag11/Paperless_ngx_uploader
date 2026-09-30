import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/models/server_config.dart';
import 'package:paperlessngx_uploader/providers/app_config_provider.dart';
import 'package:paperlessngx_uploader/providers/server_manager.dart';

/// In-memory [ServerManager] so provider tests exercise the real update methods
/// without secure storage or platform plugins.
class _InMemoryServerManager extends ServerManager {
  ServerConfig? _server;

  _InMemoryServerManager(ServerConfig? server) : _server = server;

  @override
  ServerConfig? get selectedServer => _server;

  @override
  Future<void> updateServer(ServerConfig server, {bool silent = false}) async {
    _server = server;
  }

  @override
  Future<void> saveServerCredentials(String serverId,
      {required String username, required String password}) async {}

  @override
  Future<void> saveServerApiToken(String serverId,
      {required String apiToken}) async {}
}

ServerConfig _sample() => const ServerConfig(
      id: 's1',
      name: 'server',
      serverUrl: 'https://paperless.example',
      authMethod: AuthMethod.usernamePassword,
      username: 'alice',
      allowSelfSignedCertificates: false,
      customHeaders: {'X-Proxy-Auth': 'secret'},
      defaultTagIds: [1, 2],
      askTagsBeforeUpload: true,
      favoriteTagIds: [3, 4],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerConfig.copyWith', () {
    test('preserves the fields it does not change', () {
      final updated = _sample().copyWith(allowSelfSignedCertificates: true);

      expect(updated.allowSelfSignedCertificates, isTrue);
      expect(updated.customHeaders, {'X-Proxy-Auth': 'secret'});
      expect(updated.defaultTagIds, [1, 2]);
      expect(updated.askTagsBeforeUpload, isTrue);
      expect(updated.favoriteTagIds, [3, 4]);
    });
  });

  group('ServerConfig.applyFormUpdate', () {
    test('carries over the fields the form does not manage', () {
      final existing = _sample();
      final updated = ServerConfig.applyFormUpdate(
        existing,
        id: existing.id,
        name: 'renamed',
        serverUrl: 'https://new.example',
        authMethod: AuthMethod.apiToken,
        username: null,
        allowSelfSignedCertificates: true,
        customHeaders: const {'X-Other': 'v'},
        defaultTagIds: const [9],
      );

      // Fields the form manages are taken from the arguments.
      expect(updated.name, 'renamed');
      expect(updated.serverUrl, 'https://new.example');
      expect(updated.allowSelfSignedCertificates, isTrue);
      expect(updated.customHeaders, {'X-Other': 'v'});
      expect(updated.defaultTagIds, [9]);

      // Unmanaged fields are preserved.
      expect(updated.askTagsBeforeUpload, isTrue);
      expect(updated.favoriteTagIds, [3, 4]);
    });

    test('clears custom headers when the form has none', () {
      final updated = ServerConfig.applyFormUpdate(
        _sample(),
        id: 's1',
        name: 'server',
        serverUrl: 'https://paperless.example',
        authMethod: AuthMethod.usernamePassword,
        username: 'alice',
        allowSelfSignedCertificates: false,
        customHeaders: null,
        defaultTagIds: const [],
      );

      expect(updated.customHeaders, isNull);
      expect(updated.askTagsBeforeUpload, isTrue);
    });

    test('applies defaults when adding a new server', () {
      final updated = ServerConfig.applyFormUpdate(
        null,
        id: 'new',
        name: 'new',
        serverUrl: 'https://paperless.example',
        authMethod: AuthMethod.apiToken,
        username: null,
        allowSelfSignedCertificates: false,
        customHeaders: null,
        defaultTagIds: const [],
      );

      expect(updated.askTagsBeforeUpload, isFalse);
      expect(updated.favoriteTagIds, isEmpty);
      expect(updated.customHeaders, isNull);
    });
  });

  group('AppConfigProvider updates', () {
    test('setAllowSelfSignedCertificates preserves unrelated settings',
        () async {
      final manager = _InMemoryServerManager(_sample());
      final provider = AppConfigProvider(manager);

      await provider.setAllowSelfSignedCertificates(true);

      final server = manager.selectedServer!;
      expect(server.allowSelfSignedCertificates, isTrue);
      expect(server.customHeaders, {'X-Proxy-Auth': 'secret'});
      expect(server.defaultTagIds, [1, 2]);
      expect(server.askTagsBeforeUpload, isTrue);
      expect(server.favoriteTagIds, [3, 4]);
    });

    test('saveConfiguration preserves unrelated settings', () async {
      final manager = _InMemoryServerManager(_sample());
      final provider = AppConfigProvider(manager);

      await provider.saveConfiguration('https://other.example', 'bob', 'pw');

      final server = manager.selectedServer!;
      expect(server.serverUrl, 'https://other.example');
      expect(server.username, 'bob');
      expect(server.customHeaders, {'X-Proxy-Auth': 'secret'});
      expect(server.defaultTagIds, [1, 2]);
      expect(server.askTagsBeforeUpload, isTrue);
      expect(server.favoriteTagIds, [3, 4]);
    });

    test('saveConfiguration still clears the replaced auth field', () async {
      final manager = _InMemoryServerManager(_sample());
      final provider = AppConfigProvider(manager);

      await provider.saveConfiguration('https://paperless.example', '', 'tok');

      final server = manager.selectedServer!;
      expect(server.authMethod, AuthMethod.apiToken);
      expect(server.username, isNull);
      expect(server.apiToken, 'tok');
    });
  });
}
