import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:paperless_ngx_android_uploader/services/secure_storage_service.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';
import 'package:paperless_ngx_android_uploader/providers/app_config_provider.dart';
import 'package:paperless_ngx_android_uploader/l10n/gen/app_localizations.dart';

enum _AuthMethod { userPass, apiToken } // UI enum (distinct from storage AuthMethod)

class ConfigDialog extends StatefulWidget {
  const ConfigDialog({super.key});

  @override
  State<ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<ConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureToken = true;
  _AuthMethod _authMethod = _AuthMethod.userPass;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final credentials = await SecureStorageService.getCredentials();
    setState(() {
      _serverUrlController.text = credentials['serverUrl'] ?? '';
      _usernameController.text = credentials['username'] ?? '';
      _passwordController.text = credentials['password'] ?? '';
      _tokenController.text = credentials['apiToken'] ?? '';

      // Map storage enum string to UI enum strictly to avoid cross-enum confusion.
      final methodName = credentials['authMethod'];
      switch (methodName) {
        case 'apiToken':
          _authMethod = _AuthMethod.apiToken;
          break;
        case 'usernamePassword':
          _authMethod = _AuthMethod.userPass;
          break;
        default:
          // Fallback inference
          if ((_tokenController.text.isNotEmpty) &&
              (_usernameController.text.isEmpty && _passwordController.text.isEmpty)) {
            _authMethod = _AuthMethod.apiToken;
          } else {
            _authMethod = _AuthMethod.userPass;
          }
      }
    });
  }

  Future<void> _saveAndTestConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final config = Provider.of<AppConfigProvider>(context, listen: false);

    final server = _serverUrlController.text.trim();
    // Single source of truth: let provider persist via SecureStorageService internally.
    if (_authMethod == _AuthMethod.userPass) {
      await config.saveConfiguration(
        server,
        _usernameController.text.trim(),
        _passwordController.text,
      );
    } else {
      // Token mode: pass empty username so provider infers AuthMethod.apiToken
      await config.saveConfiguration(
        server,
        '',
        _tokenController.text,
      );
    }

    await config.testConnection();

    if (mounted && config.connectionStatus == ConnectionStatus.connected) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.dialog_title_paperless_configuration),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _serverUrlController,
                decoration: InputDecoration(
                  labelText: l10n.field_label_server_url,
                  hintText: l10n.field_hint_server_url_example,
                  prefixIcon: const Icon(Icons.link),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.validation_enter_server_url;
                  }
                  if (!value.startsWith('http://') && !value.startsWith('https://')) {
                    return l10n.validation_enter_valid_url;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Authentication method selector (Dropdown)
              DropdownButtonFormField<_AuthMethod>(
                value: _authMethod,
                decoration: const InputDecoration(
                  labelText: 'Authentication Method',
                  prefixIcon: Icon(Icons.security),
                ),
                items: const [
                  DropdownMenuItem(
                    value: _AuthMethod.userPass,
                    child: Text('Username / Password'),
                  ),
                  DropdownMenuItem(
                    value: _AuthMethod.apiToken,
                    child: Text('API Token'),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _authMethod = val;
                  });
                },
              ),
              const SizedBox(height: 8),

              // Conditional fields
              if (_authMethod == _AuthMethod.userPass) ...[
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: l10n.field_label_username,
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    // Validate only in Username/Password mode
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
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.field_label_password,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    // Validate only in Username/Password mode
                    if (_authMethod == _AuthMethod.userPass) {
                      if (value == null || value.isEmpty) {
                        return l10n.validation_enter_password;
                      }
                    }
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  decoration: InputDecoration(
                    labelText: 'API Token',
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureToken = !_obscureToken;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    // Validate only in API Token mode
                    if (_authMethod == _AuthMethod.apiToken) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter API token';
                      }
                    }
                    return null;
                  },
                ),
              ],

              Consumer<AppConfigProvider>(
                builder: (context, config, child) {
                  if (config.connectionError != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        config.connectionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.action_cancel),
        ),
        Consumer<AppConfigProvider>(
          builder: (context, config, child) {
            final isConnecting = config.connectionStatus == ConnectionStatus.connecting;
            return ElevatedButton(
              onPressed: isConnecting ? null : _saveAndTestConnection,
              child: isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.action_save_and_test),
            );
          },
        ),
      ],
    );
  }
}