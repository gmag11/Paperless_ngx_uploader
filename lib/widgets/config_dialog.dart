import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:paperlessngx_uploader/models/connection_status.dart';
import 'package:paperlessngx_uploader/providers/server_manager.dart';
import 'package:paperlessngx_uploader/models/server_config.dart';
import 'package:paperlessngx_uploader/l10n/gen/app_localizations.dart';
import 'package:paperlessngx_uploader/services/client_certificate.dart';
import 'package:paperlessngx_uploader/services/paperless_service_factory.dart';
import 'package:paperlessngx_uploader/services/secure_storage_service.dart';
import 'package:paperlessngx_uploader/utils/ui_helper.dart';

enum _AuthMethod { userPass, apiToken }

enum _CertificateFileKind { certificate, privateKey, customCa }

enum _CertificateInputMode { file, paste }

/// Raised when the client-certificate form input is invalid; carries the
/// localized message to show inline.
class _ClientCertificateValidation implements Exception {
  final String message;

  const _ClientCertificateValidation(this.message);
}

class ConfigDialog extends StatefulWidget {
  const ConfigDialog({super.key});

  @override
  State<ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<ConfigDialog> {
  final _serverFormKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();
  final _serverNameController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureToken = true;

  bool _passwordLoadedFromStorage = false;
  bool _tokenLoadedFromStorage = false;

  String? _inlineConnectionError;
  bool _localConnecting = false;

  _AuthMethod _authMethod = _AuthMethod.userPass;

  bool _showServerForm = false;
  String? _editingServerId;

  // TLS trust policy of the server being edited (form-local, committed on save).
  bool _allowSelfSignedCertificates = false;

  // Client certificate (mutual TLS) form state.
  bool _useClientCertificate = false;
  ClientCertificateFormat _clientCertificateFormat = ClientCertificateFormat.pkcs12;
  List<int>? _clientCertificateBytes;
  String? _clientCertificateName;
  List<int>? _clientPrivateKeyBytes;
  String? _clientPrivateKeyName;
  final _clientCertificatePasswordController = TextEditingController();
  List<int>? _customCaBytes;
  String? _customCaName;
  String? _clientCertificateInlineError;
  _CertificateInputMode _clientCertificateInput = _CertificateInputMode.file;
  _CertificateInputMode _clientPrivateKeyInput = _CertificateInputMode.file;
  _CertificateInputMode _customCaInput = _CertificateInputMode.file;
  final _clientCertificateTextController = TextEditingController();
  final _clientPrivateKeyTextController = TextEditingController();
  final _customCaTextController = TextEditingController();

  bool get _isIos => Platform.isIOS;

  // Custom headers state
  final List<({TextEditingController keyController, TextEditingController valueController})>
      _customHeaderRows = [];

  @override
  void initState() {
    super.initState();
    developer.log('ConfigDialog initState - _showServerForm: $_showServerForm', name: 'ConfigDialog');
    _loadCurrentServer();
  }

  Future<void> _loadCurrentServer() async {
    final serverManager = Provider.of<ServerManager>(context, listen: false);
    final currentServer = serverManager.selectedServer;
    
    developer.log('_loadCurrentServer - currentServer: $currentServer', name: 'ConfigDialog');
    
    if (currentServer != null) {
      final credentials = await serverManager.getServerCredentials(currentServer.id);
      
      setState(() {
        _serverNameController.text = currentServer.name;
        _serverUrlController.text = currentServer.serverUrl;
        _allowSelfSignedCertificates = currentServer.allowSelfSignedCertificates;
        
        if (currentServer.authMethod == AuthMethod.usernamePassword) {
          _authMethod = _AuthMethod.userPass;
          _usernameController.text = currentServer.username ?? '';
          _passwordController.text = credentials['password'] ?? '';
          _tokenController.text = '';
          
          _passwordLoadedFromStorage = credentials['password']?.isNotEmpty == true;
          _tokenLoadedFromStorage = false;
        } else {
          _authMethod = _AuthMethod.apiToken;
          _tokenController.text = credentials['apiToken'] ?? '';
          _usernameController.text = '';
          _passwordController.text = '';
          
          _tokenLoadedFromStorage = credentials['apiToken']?.isNotEmpty == true;
          _passwordLoadedFromStorage = false;
        }
        
        _obscurePassword = true;
        _obscureToken = true;
        _editingServerId = currentServer.id;
        _showServerForm = false; // Ensure we show server list when loading current server

        // Load custom headers
        _customHeaderRows.clear();
        final customHeaders = currentServer.customHeaders;
        if (customHeaders != null && customHeaders.isNotEmpty) {
          for (final entry in customHeaders.entries) {
            _customHeaderRows.add((
              keyController: TextEditingController(text: entry.key),
              valueController: TextEditingController(text: entry.value),
            ));
          }
        }
      });
    }
  }

  Future<void> _loadServerForEdit(ServerConfig server) async {
    if (!mounted) return;
    final credentials = await Provider.of<ServerManager>(context, listen: false)
        .getServerCredentials(server.id);
    
    if (!mounted) return;
    setState(() {
      _serverNameController.text = server.name;
      _serverUrlController.text = server.serverUrl;
      
      if (server.authMethod == AuthMethod.usernamePassword) {
        _authMethod = _AuthMethod.userPass;
        _usernameController.text = server.username ?? '';
        _passwordController.text = credentials['password'] ?? '';
        _tokenController.text = '';
        
        _passwordLoadedFromStorage = credentials['password']?.isNotEmpty == true;
        _tokenLoadedFromStorage = false;
      } else {
        _authMethod = _AuthMethod.apiToken;
        _tokenController.text = credentials['apiToken'] ?? '';
        _usernameController.text = '';
        _passwordController.text = '';
        
        _tokenLoadedFromStorage = credentials['apiToken']?.isNotEmpty == true;
        _passwordLoadedFromStorage = false;
      }
      
      _obscurePassword = true;
      _obscureToken = true;
      _editingServerId = server.id;
      _showServerForm = true;
      _allowSelfSignedCertificates = server.allowSelfSignedCertificates;

      // Load client certificate and custom headers
      _useClientCertificate = server.useClientCertificate;
      _clientCertificateFormat = server.clientCertificateFormat;
      _customHeaderRows.clear();
      final customHeaders = server.customHeaders;
      if (customHeaders != null && customHeaders.isNotEmpty) {
        for (final entry in customHeaders.entries) {
          _customHeaderRows.add((
            keyController: TextEditingController(text: entry.key),
            valueController: TextEditingController(text: entry.value),
          ));
        }
      }
    });

    if (server.useClientCertificate || server.hasCustomCa) {
      final storage = SecureStorageService();
      final certificate = await storage.getServerClientCertificate(server.id);
      final privateKey = await storage.getServerClientPrivateKey(server.id);
      final password = await storage.getServerClientCertificatePassword(server.id);
      final customCa = await storage.getServerCustomCa(server.id);
      if (!mounted) return;
      setState(() {
        _clientCertificateBytes = certificate;
        _clientPrivateKeyBytes = privateKey;
        _clientCertificatePasswordController.text = password ?? '';
        _customCaBytes = customCa;
      });
    }
  }

  void _clearForm() {
    setState(() {
      _serverNameController.clear();
      _serverUrlController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _tokenController.clear();
      
      _authMethod = _AuthMethod.userPass;
      _obscurePassword = true;
      _obscureToken = true;
      _passwordLoadedFromStorage = false;
      _tokenLoadedFromStorage = false;
      _inlineConnectionError = null;
      _editingServerId = null;
      _showServerForm = false;
      _allowSelfSignedCertificates = false;

      _useClientCertificate = false;
      _clientCertificateFormat = ClientCertificateFormat.pkcs12;
      _clientCertificateBytes = null;
      _clientCertificateName = null;
      _clientPrivateKeyBytes = null;
      _clientPrivateKeyName = null;
      _clientCertificatePasswordController.clear();
      _customCaBytes = null;
      _customCaName = null;
      _clientCertificateInlineError = null;
      _clientCertificateInput = _CertificateInputMode.file;
      _clientPrivateKeyInput = _CertificateInputMode.file;
      _customCaInput = _CertificateInputMode.file;
      _clientCertificateTextController.clear();
      _clientPrivateKeyTextController.clear();
      _customCaTextController.clear();

      // Clear custom headers
      for (final row in _customHeaderRows) {
        row.keyController.dispose();
        row.valueController.dispose();
      }
      _customHeaderRows.clear();
    });
  }

  void _addCustomHeaderRow() {
    setState(() {
      _customHeaderRows.add((
        keyController: TextEditingController(),
        valueController: TextEditingController(),
      ));
    });
  }

  void _removeCustomHeaderRow(int index) {
    setState(() {
      final row = _customHeaderRows.removeAt(index);
      row.keyController.dispose();
      row.valueController.dispose();
    });
  }

  Map<String, String> _collectCustomHeaders() {
    final headers = <String, String>{};
    for (final row in _customHeaderRows) {
      final key = row.keyController.text.trim();
      final value = row.valueController.text.trim();
      if (key.isNotEmpty) {
        headers[key] = value;
      }
      // Empty-key rows with empty values are silently skipped
    }
    return headers;
  }

  bool _validateCustomHeaders() {
    for (final row in _customHeaderRows) {
      final key = row.keyController.text.trim();
      final value = row.valueController.text.trim();
      // Key is empty but value is not: reject
      if (key.isEmpty && value.isNotEmpty) {
        return false;
      }
      // Key is not empty but value is empty: reject
      if (key.isNotEmpty && value.isEmpty) {
        return false;
      }
      // Both empty: silently skip (handled in _collectCustomHeaders)
      // Both non-empty: valid
    }
    return true;
  }

  Future<void> _saveAndTestServer() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_serverFormKey.currentState!.validate()) {
      return;
    }

    if (mounted) {
      setState(() {
        _inlineConnectionError = null;
        _localConnecting = true;
      });
    }

    if (!mounted) return;
    final serverManager = Provider.of<ServerManager>(context, listen: false);

    var serverUrl = _serverUrlController.text.trim();

    // Validate and collect custom headers early so they're available for protocol detection
    if (!_validateCustomHeaders()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.validation_custom_header_incomplete),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    ClientCertificateMaterial? clientCertificate;
    try {
      clientCertificate = _clientCertificateMaterial(l10n);
      if (mounted) {
        setState(() => _clientCertificateInlineError = null);
      }
    } on _ClientCertificateValidation catch (e) {
      if (mounted) {
        setState(() {
          _clientCertificateInlineError = e.message;
          _localConnecting = false;
        });
      }
      return;
    }

    final customHeaders = _collectCustomHeaders();
    
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      serverUrl = await _determineProtocol(
          serverUrl, customHeaders.isNotEmpty ? customHeaders : null, clientCertificate);
      if (serverUrl.isEmpty) {
        if (mounted) {
          setState(() {
            _localConnecting = false;
          });
        }
        return;
      }
    }

    final username = _authMethod == _AuthMethod.userPass ? _usernameController.text.trim() : '';
    final secret = _authMethod == _AuthMethod.userPass ? _passwordController.text : _tokenController.text;
    final useApi = _authMethod == _AuthMethod.apiToken;

    // The server being edited (null when adding a new one), used to carry over
    // the settings the form does not touch.
    final existingServer = _editingServerId != null
        ? serverManager.getServer(_editingServerId!)
        : null;

    final draftConfig = ServerConfig.applyFormUpdate(
      existingServer,
      id: _editingServerId ?? ServerConfig.generateId(),
      name: _serverNameController.text.trim(),
      serverUrl: serverUrl,
      authMethod: useApi ? AuthMethod.apiToken : AuthMethod.usernamePassword,
      username: useApi ? null : username,
      allowSelfSignedCertificates: _allowSelfSignedCertificates,
      customHeaders: customHeaders.isNotEmpty ? customHeaders : null,
      defaultTagIds: existingServer?.defaultTagIds ?? const [],
      useClientCertificate: clientCertificate?.hasClientCertificate ?? false,
      clientCertificateFormat: _clientCertificateFormat,
      hasCustomCa: clientCertificate?.customCa != null,
    );

    final tempService = PaperlessServiceFactory.createServiceForConfig(
      draftConfig,
      password: useApi ? null : secret,
      apiToken: useApi ? secret : null,
      clientCertificate: clientCertificate,
    );

    final status = await tempService.testConnection();

    if (mounted) {
      setState(() {
        _localConnecting = false;
      });
    }

    if (status == ConnectionStatus.connected) {
      // Preserve the server's existing default tags when updating it.
      final existingDefaultTagIds = existingServer?.defaultTagIds ?? const <int>[];
      developer.log('Preserving existing defaultTagIds: $existingDefaultTagIds', name: 'ConfigDialog');

      if (!mounted) return;
      final serverId = _editingServerId ?? ServerConfig.generateId();
      
      developer.log('Creating/updating server with ID: $serverId', name: 'ConfigDialog');
      developer.log('Server name: ${_serverNameController.text.trim()}', name: 'ConfigDialog');
      developer.log('Server URL: $serverUrl', name: 'ConfigDialog');
      developer.log('Auth method: ${_authMethod == _AuthMethod.apiToken ? "API Token" : "Username/Password"}', name: 'ConfigDialog');

      final server = ServerConfig.applyFormUpdate(
        existingServer,
        id: serverId,
        name: _serverNameController.text.trim(),
        serverUrl: serverUrl,
        authMethod: _authMethod == _AuthMethod.apiToken
            ? AuthMethod.apiToken
            : AuthMethod.usernamePassword,
        username: _authMethod == _AuthMethod.userPass ? username : null,
        allowSelfSignedCertificates: _allowSelfSignedCertificates,
        customHeaders: customHeaders.isNotEmpty ? customHeaders : null,
        defaultTagIds: existingDefaultTagIds,
        useClientCertificate: clientCertificate?.hasClientCertificate ?? false,
        clientCertificateFormat: _clientCertificateFormat,
        hasCustomCa: clientCertificate?.customCa != null,
      );

      try {
        if (_editingServerId != null) {
          developer.log('Updating existing server: ${server.id}', name: 'ConfigDialog');
          await serverManager.updateServer(server);
        } else {
          developer.log('Adding new server: ${server.id}', name: 'ConfigDialog');
          await serverManager.addServer(server);
        }

        developer.log('Saving credentials for server: ${server.id}', name: 'ConfigDialog');
        if (_authMethod == _AuthMethod.userPass) {
          await serverManager.saveServerCredentials(server.id,
              username: username, password: secret);
          developer.log('Username/password credentials saved', name: 'ConfigDialog');
        } else {
          await serverManager.saveServerApiToken(server.id, apiToken: secret);
          developer.log('API token saved', name: 'ConfigDialog');
        }

        developer.log('Saving client certificate settings', name: 'ConfigDialog');
        final storage = SecureStorageService();
        final material = clientCertificate;
        if (material != null && material.hasClientCertificate) {
          await storage.saveServerClientCertificate(server.id, material.certificate!);
          if (_clientCertificateFormat == ClientCertificateFormat.pem &&
              material.privateKey != null) {
            await storage.saveServerClientPrivateKey(server.id, material.privateKey!);
          } else {
            await storage.deleteServerClientPrivateKey(server.id);
          }
          await storage.saveServerClientCertificatePassword(
              server.id, material.password ?? '');
        } else {
          await storage.deleteServerClientCertificate(server.id);
          await storage.deleteServerClientPrivateKey(server.id);
          await storage.deleteServerClientCertificatePassword(server.id);
        }
        final customCa = material?.customCa;
        if (customCa != null) {
          await storage.saveServerCustomCa(server.id, customCa);
        } else {
          await storage.deleteServerCustomCa(server.id);
        }

        developer.log('Selecting server: ${server.id}', name: 'ConfigDialog');
        await serverManager.selectServer(server.id);

        developer.log('Server configuration completed successfully', name: 'ConfigDialog');

        UIHelper.showMessage(context, l10n.connectionSuccess, success: true);

        if (mounted) {
          _clearForm();
        }
      } catch (e) {
        developer.log('Error saving server configuration: $e', name: 'ConfigDialog');
        if (mounted) {
          setState(() {
            _inlineConnectionError = l10n.error_unknown;
          });
        }
      }
    } else {
      if (mounted) {
        final isTokenMode = _authMethod == _AuthMethod.apiToken;
        final err = switch (status) {
          ConnectionStatus.invalidCredentials => isTokenMode
              ? l10n.error_invalid_token
              : l10n.error_invalid_credentials,
          ConnectionStatus.serverUnreachable => l10n.error_server_unreachable,
          ConnectionStatus.invalidServerUrl => l10n.error_invalid_server,
          ConnectionStatus.sslError => l10n.error_ssl,
          ConnectionStatus.clientCertificateError => l10n.error_client_certificate,
          ConnectionStatus.clientCertificateRequired =>
            l10n.error_client_certificate_required,
          ConnectionStatus.clientCertificatePasswordError =>
            l10n.error_client_certificate_password,
          ConnectionStatus.unknownError => l10n.error_unknown,
          _ => l10n.error_unknown,
        };
        setState(() {
          _inlineConnectionError = err;
        });
      }
    }
  }

  /// Resolves the client certificate material from the form, decoding pasted
  /// text when an artifact is in paste mode.
  ///
  /// Returns null when neither a client certificate nor a custom CA is
  /// configured. Throws [_ClientCertificateValidation] (with a localized
  /// message) when the input is incomplete or cannot be decoded.
  /// Resolves the client certificate material from the form, or null when
  /// mutual TLS is disabled (the certificate and custom CA are only part of the
  /// mTLS configuration).
  ClientCertificateMaterial? _clientCertificateMaterial(AppLocalizations l10n) {
    if (!_useClientCertificate) return null;

    final certificate = _resolveCertificateArtifact(
      mode: _clientCertificateInput,
      text: _clientCertificateTextController.text,
      fileBytes: _clientCertificateBytes,
      format: _clientCertificateFormat,
      emptyMessage: l10n.validation_client_certificate_required,
      invalidMessage: l10n.validation_client_certificate_invalid,
    );

    List<int>? privateKey;
    if (_clientCertificateFormat == ClientCertificateFormat.pem) {
      privateKey = _resolveCertificateArtifact(
        mode: _clientPrivateKeyInput,
        text: _clientPrivateKeyTextController.text,
        fileBytes: _clientPrivateKeyBytes,
        format: ClientCertificateFormat.pem,
        emptyMessage: l10n.validation_client_private_key_required,
        invalidMessage: l10n.validation_client_private_key_invalid,
      );
    }

    final customCa = _resolveCertificateArtifact(
      mode: _customCaInput,
      text: _customCaTextController.text,
      fileBytes: _customCaBytes,
      format: ClientCertificateFormat.pem,
      emptyMessage: null,
      invalidMessage: l10n.validation_custom_ca_invalid,
    );

    return ClientCertificateMaterial(
      format: _clientCertificateFormat,
      certificate: certificate,
      privateKey: privateKey,
      password: _clientCertificatePasswordController.text,
      customCa: customCa,
    );
  }

  /// Resolves one artifact from either a picked file or pasted text.
  List<int>? _resolveCertificateArtifact({
    required _CertificateInputMode mode,
    required String text,
    required List<int>? fileBytes,
    required ClientCertificateFormat format,
    required String? emptyMessage,
    required String invalidMessage,
  }) {
    if (mode == _CertificateInputMode.paste) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        if (emptyMessage == null) return null;
        throw _ClientCertificateValidation(emptyMessage);
      }
      try {
        return decodePastedCertificate(trimmed, format);
      } on PastedCertificateException {
        throw _ClientCertificateValidation(invalidMessage);
      }
    }
    if (fileBytes == null || fileBytes.isEmpty) {
      if (emptyMessage == null) return null;
      throw _ClientCertificateValidation(emptyMessage);
    }
    return fileBytes;
  }

  void _clearCustomCaForm() {
    _customCaBytes = null;
    _customCaName = null;
    _customCaInput = _CertificateInputMode.file;
    _customCaTextController.clear();
  }

  Future<void> _pickCertificateFile(_CertificateFileKind kind) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final file = await openFile();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        switch (kind) {
          case _CertificateFileKind.certificate:
            _clientCertificateBytes = bytes;
            _clientCertificateName = file.name;
          case _CertificateFileKind.privateKey:
            _clientPrivateKeyBytes = bytes;
            _clientPrivateKeyName = file.name;
          case _CertificateFileKind.customCa:
            _customCaBytes = bytes;
            _customCaName = file.name;
        }
        _clientCertificateInlineError = null;
      });
    } catch (e) {
      developer.log('Certificate file pick failed: $e', name: 'ConfigDialog');
      if (mounted) {
        setState(() => _clientCertificateInlineError = l10n.error_unknown);
      }
    }
  }

  Widget _buildCertificateInput({
    required String label,
    required _CertificateInputMode mode,
    required ValueChanged<_CertificateInputMode> onModeChanged,
    required String? fileName,
    required bool hasFile,
    required VoidCallback onPick,
    required TextEditingController controller,
    required String pasteHint,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isPaste = mode == _CertificateInputMode.paste;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(label)),
                    if (hasFile && !isPaste) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.green),
                    ],
                  ],
                ),
              ),
              SegmentedButton<_CertificateInputMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: _CertificateInputMode.file,
                    label: Text(l10n.action_input_file),
                  ),
                  ButtonSegment(
                    value: _CertificateInputMode.paste,
                    label: Text(l10n.action_input_paste),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => onModeChanged(selection.first),
              ),
            ],
          ),
          if (isPaste)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                // Fixed height with internal vertical scrolling so a full PEM
                // block is comfortable to read and edit.
                height: 200,
                child: TextFormField(
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    hintText: pasteHint,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                TextButton(
                  onPressed: onPick,
                  child: Text(l10n.action_choose_file),
                ),
                if (fileName != null)
                  Flexible(
                    child: Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildClientCertificateSection(AppLocalizations l10n) {
    final isPem = _clientCertificateFormat == ClientCertificateFormat.pem;
    return ExpansionTile(
      title: Text(l10n.section_title_client_certificate),
      leading: const Icon(Icons.badge_outlined),
      initiallyExpanded: _useClientCertificate,
      children: [
        SwitchListTile(
          title: Text(l10n.section_title_client_certificate),
          value: _useClientCertificate,
          onChanged: (value) {
            setState(() {
              _useClientCertificate = value;
              if (!value) {
                _clientCertificateInlineError = null;
                // The custom CA is part of the mTLS configuration; drop it when
                // the section is disabled so no hidden state lingers.
                _clearCustomCaForm();
              }
            });
          },
        ),
        if (_useClientCertificate) ...[
          if (!_isIos)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<ClientCertificateFormat>(
                initialValue: _clientCertificateFormat,
                decoration: InputDecoration(
                  labelText: l10n.label_certificate_format,
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                    value: ClientCertificateFormat.pkcs12,
                    child: Text(l10n.certificate_format_pkcs12),
                  ),
                  DropdownMenuItem(
                    value: ClientCertificateFormat.pem,
                    child: Text(l10n.certificate_format_pem),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _clientCertificateFormat = value);
                  }
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(l10n.certificate_pem_unavailable_ios,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          _buildCertificateInput(
            label: l10n.field_label_client_certificate,
            mode: _clientCertificateInput,
            onModeChanged: (mode) =>
                setState(() => _clientCertificateInput = mode),
            fileName: _clientCertificateName,
            hasFile: _clientCertificateBytes != null,
            onPick: () => _pickCertificateFile(_CertificateFileKind.certificate),
            controller: _clientCertificateTextController,
            pasteHint: isPem
                ? l10n.field_hint_paste_pem
                : l10n.field_hint_paste_base64,
          ),
          if (isPem)
            _buildCertificateInput(
              label: l10n.field_label_client_private_key,
              mode: _clientPrivateKeyInput,
              onModeChanged: (mode) =>
                  setState(() => _clientPrivateKeyInput = mode),
              fileName: _clientPrivateKeyName,
              hasFile: _clientPrivateKeyBytes != null,
              onPick: () => _pickCertificateFile(_CertificateFileKind.privateKey),
              controller: _clientPrivateKeyTextController,
              pasteHint: l10n.field_hint_paste_pem,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextFormField(
              controller: _clientCertificatePasswordController,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.field_label_client_certificate_password,
                prefixIcon: const Icon(Icons.lock),
                isDense: true,
              ),
            ),
          ),
          ExpansionTile(
            title: Text(l10n.section_title_advanced),
            leading: const Icon(Icons.tune),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            initiallyExpanded: _customCaBytes != null ||
                _customCaTextController.text.trim().isNotEmpty,
            children: [
              _buildCertificateInput(
                label: l10n.field_label_custom_ca,
                mode: _customCaInput,
                onModeChanged: (mode) => setState(() => _customCaInput = mode),
                fileName: _customCaName,
                hasFile: _customCaBytes != null,
                onPick: () => _pickCertificateFile(_CertificateFileKind.customCa),
                controller: _customCaTextController,
                pasteHint: l10n.field_hint_paste_pem,
              ),
            ],
          ),
          if (_clientCertificateInlineError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _clientCertificateInlineError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.action_remove_client_certificate),
              onPressed: () {
                setState(() {
                  _useClientCertificate = false;
                  _clientCertificateBytes = null;
                  _clientCertificateName = null;
                  _clientPrivateKeyBytes = null;
                  _clientPrivateKeyName = null;
                  _clientCertificatePasswordController.clear();
                  _clientCertificateInput = _CertificateInputMode.file;
                  _clientPrivateKeyInput = _CertificateInputMode.file;
                  _clientCertificateTextController.clear();
                  _clientPrivateKeyTextController.clear();
                  _clearCustomCaForm();
                  _clientCertificateInlineError = null;
                });
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<String> _determineProtocol(
    String serverWithoutProtocol,
    Map<String, String>? customHeaders,
    ClientCertificateMaterial? clientCertificate,
  ) async {
    final username = _authMethod == _AuthMethod.userPass ? _usernameController.text.trim() : '';
    final secret = _authMethod == _AuthMethod.userPass ? _passwordController.text : _tokenController.text;
    final useApi = _authMethod == _AuthMethod.apiToken;

    // Both attempts use the same draft configuration and therefore the same
    // transport rules (auth, custom headers, TLS trust policy, client cert).
    ServerConfig draftConfig(String url) => ServerConfig(
          id: _editingServerId ?? ServerConfig.generateId(),
          name: _serverNameController.text.trim(),
          serverUrl: url,
          authMethod: useApi ? AuthMethod.apiToken : AuthMethod.usernamePassword,
          username: useApi ? null : username,
          allowSelfSignedCertificates: _allowSelfSignedCertificates,
          customHeaders: customHeaders,
          useClientCertificate: clientCertificate?.hasClientCertificate ?? false,
          clientCertificateFormat: _clientCertificateFormat,
          hasCustomCa: clientCertificate?.customCa != null,
        );

    final httpsServer = 'https://$serverWithoutProtocol';
    final httpsService = PaperlessServiceFactory.createServiceForConfig(
      draftConfig(httpsServer),
      password: useApi ? null : secret,
      apiToken: useApi ? secret : null,
      clientCertificate: clientCertificate,
    );

    final httpsStatus = await httpsService.testConnection();
    
    if (httpsStatus == ConnectionStatus.connected) {
      return httpsServer;
    }

    final httpServer = 'http://$serverWithoutProtocol';
    final httpService = PaperlessServiceFactory.createServiceForConfig(
      draftConfig(httpServer),
      password: useApi ? null : secret,
      apiToken: useApi ? secret : null,
      clientCertificate: clientCertificate,
    );

    final httpStatus = await httpService.testConnection();
    
    if (httpStatus == ConnectionStatus.connected) {
      return httpServer;
    }

    return httpServer;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    _serverNameController.dispose();
    _clientCertificatePasswordController.dispose();
    _clientCertificateTextController.dispose();
    _clientPrivateKeyTextController.dispose();
    _customCaTextController.dispose();
    for (final row in _customHeaderRows) {
      row.keyController.dispose();
      row.valueController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    developer.log('ConfigDialog build - _showServerForm: $_showServerForm', name: 'ConfigDialog');
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.dialog_title_paperless_configuration),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: Consumer<ServerManager>(
            builder: (context, serverManager, child) {
              developer.log('ConfigDialog Consumer - _showServerForm: $_showServerForm, servers: ${serverManager.servers.length}', name: 'ConfigDialog');
              if (_showServerForm) {
                developer.log('Showing server form', name: 'ConfigDialog');
                return _buildServerForm();
              } else {
                developer.log('Showing server list', name: 'ConfigDialog');
                return _buildServerList(serverManager);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildServerList(ServerManager serverManager) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: serverManager.servers.length,
            itemBuilder: (context, index) {
              final server = serverManager.servers[index];
              final isSelected = server.id == serverManager.selectedServer?.id;
              
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(server.name),
                subtitle: Text(server.serverUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: l10n.action_edit,
                      onPressed: () => _loadServerForEdit(server),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: l10n.action_delete,
                      onPressed: () => _confirmDeleteServer(server),
                    ),
                  ],
                ),
                onTap: () async {
                  await serverManager.selectServer(server.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                selected: isSelected,
                tileColor: isSelected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : null,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.action_add_server),
                  onPressed: () {
                    developer.log('Add Server button clicked', name: 'ConfigDialog');
                    developer.log('Current _showServerForm: $_showServerForm', name: 'ConfigDialog');
                    setState(() {
                      _editingServerId = null;
                      _clearForm();
                      _showServerForm = true; // Set this AFTER _clearForm()
                    });
                    developer.log('After setState - _showServerForm: $_showServerForm', name: 'ConfigDialog');
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerForm() {
    final l10n = AppLocalizations.of(context)!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _serverFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _serverNameController,
              decoration: InputDecoration(
                labelText: l10n.field_label_server_name,
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.validation_enter_server_name;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _serverUrlController,
              autofillHints: const [AutofillHints.url],
              decoration: InputDecoration(
                labelText: l10n.field_label_server_url,
                hintText: l10n.field_hint_server_url_example,
                prefixIcon: const Icon(Icons.link),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.validation_enter_server_url;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<_AuthMethod>(
              initialValue: _authMethod,
              decoration: InputDecoration(
                labelText: l10n.field_label_auth_method,
                prefixIcon: const Icon(Icons.security),
              ),
              items: [
                DropdownMenuItem(
                  value: _AuthMethod.userPass,
                  child: Text(l10n.field_option_auth_user_pass),
                ),
                DropdownMenuItem(
                  value: _AuthMethod.apiToken,
                  child: Text(l10n.field_option_auth_token),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _authMethod = val;
                  _obscurePassword = true;
                  _obscureToken = true;
                });
              },
            ),
            const SizedBox(height: 8),
            if (_authMethod == _AuthMethod.userPass) ...[
              TextFormField(
                controller: _usernameController,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(
                  labelText: l10n.field_label_username,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (_authMethod == _AuthMethod.userPass) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.validation_enter_username;
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                autofillHints: const [AutofillHints.password],
                keyboardType: TextInputType.visiblePassword,
                obscureText: _passwordLoadedFromStorage ? true : _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                onTap: () {
                  if (_passwordLoadedFromStorage) {
                    setState(() {
                      _passwordController.clear();
                      _passwordLoadedFromStorage = false;
                      _obscurePassword = true;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: l10n.field_label_password,
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      if (!_passwordLoadedFromStorage) {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      }
                    },
                  ),
                ),
                validator: (value) {
                  if (_authMethod == _AuthMethod.userPass) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.validation_enter_password;
                    }
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _tokenController,
                autofillHints: const [AutofillHints.password],
                obscureText: _tokenLoadedFromStorage ? true : _obscureToken,
                enableSuggestions: false,
                autocorrect: false,
                onTap: () {
                  if (_tokenLoadedFromStorage) {
                    setState(() {
                      _tokenController.clear();
                      _tokenLoadedFromStorage = false;
                      _obscureToken = true;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: l10n.field_label_api_token,
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      if (!_tokenLoadedFromStorage) {
                        setState(() {
                          _obscureToken = !_obscureToken;
                        });
                      }
                    },
                  ),
                ),
                validator: (value) {
                  if (_authMethod == _AuthMethod.apiToken) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.validation_enter_token;
                    }
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.allow_self_signed_certificates),
              value: _allowSelfSignedCertificates,
              onChanged: (value) {
                setState(() {
                  _allowSelfSignedCertificates = value;
                });
              },
            ),
            const SizedBox(height: 8),
            _buildClientCertificateSection(l10n),
            const SizedBox(height: 8),
            // Custom Headers section
            ExpansionTile(
              title: Text(l10n.section_title_custom_headers),
              leading: const Icon(Icons.http),
              initiallyExpanded: _customHeaderRows.isNotEmpty,
              children: [
                ..._customHeaderRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: row.keyController,
                            decoration: InputDecoration(
                              labelText: l10n.field_label_header_key,
                              hintText: l10n.field_hint_header_key,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: row.valueController,
                            decoration: InputDecoration(
                              labelText: l10n.field_label_header_value,
                              hintText: l10n.field_hint_header_value,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: l10n.action_remove_header,
                          onPressed: () => _removeCustomHeaderRow(index),
                        ),
                      ],
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.action_add_header),
                    onPressed: _addCustomHeaderRow,
                  ),
                ),
              ],
            ),
            if (_inlineConnectionError != null) ...[
              const SizedBox(height: 8),
              Text(
                _inlineConnectionError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showServerForm = false;
                      _clearForm();
                    });
                  },
                  child: Text(l10n.action_cancel),
                ),
                ElevatedButton(
                  onPressed: _localConnecting
                      ? null
                      : _saveAndTestServer,
                  child: _localConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.action_save_and_test),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteServer(ServerConfig server) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.action_delete_server),
        content: Text(l10n.message_delete_server_confirmation(server.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.action_cancel),
          ),
          TextButton(
            onPressed: () async {
              if (!context.mounted) return;
              await Provider.of<ServerManager>(context, listen: false)
                  .removeServer(server.id);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              l10n.action_delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}