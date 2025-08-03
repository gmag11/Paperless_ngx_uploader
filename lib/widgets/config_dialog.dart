import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:paperless_ngx_android_uploader/services/secure_storage_service.dart';
import 'package:paperless_ngx_android_uploader/models/connection_status.dart';
import 'package:paperless_ngx_android_uploader/providers/app_config_provider.dart';
import 'package:paperless_ngx_android_uploader/l10n/gen/app_localizations.dart';

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

  bool _obscurePassword = true;

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
    });
  }

  Future<void> _saveAndTestConnection() async {
    if (!_formKey.currentState!.validate()) return;

    final config = Provider.of<AppConfigProvider>(context, listen: false);
    await config.saveConfiguration(
      _serverUrlController.text.trim(),
      _usernameController.text.trim(),
      _passwordController.text,
    );
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
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: l10n.field_label_username,
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.validation_enter_username;
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
                  if (value == null || value.isEmpty) {
                    return l10n.validation_enter_password;
                  }
                  return null;
                },
              ),
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