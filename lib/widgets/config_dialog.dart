import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer' as developer;

import 'package:paperlessngx_uploader/models/connection_status.dart';
import 'package:paperlessngx_uploader/providers/app_config_provider.dart';
import 'package:paperlessngx_uploader/providers/server_manager.dart';
import 'package:paperlessngx_uploader/models/server_config.dart';
import 'package:paperlessngx_uploader/l10n/gen/app_localizations.dart';
import 'package:paperlessngx_uploader/services/paperless_service.dart';

enum _AuthMethod { userPass, apiToken }

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
    });
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
    });
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
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    final serverManager = Provider.of<ServerManager>(context, listen: false);

    var serverUrl = _serverUrlController.text.trim();
    
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      serverUrl = await _determineProtocol(serverUrl, config);
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

    final tempService = PaperlessService(
      baseUrl: serverUrl,
      username: username,
      password: useApi ? '' : secret,
      useApiToken: useApi,
      apiToken: useApi ? secret : null,
      allowSelfSignedCertificates: config.allowSelfSignedCertificates,
    );

    final status = await tempService.testConnection();

    if (mounted) {
      setState(() {
        _localConnecting = false;
      });
    }

    if (status == ConnectionStatus.connected) {
      // Preserve existing defaultTagIds when updating server
      List<int> existingDefaultTagIds = [];
      if (_editingServerId != null) {
        if (!mounted) return;
        final serverManager = Provider.of<ServerManager>(context, listen: false);
        final existingServer = serverManager.getServer(_editingServerId!);
        if (existingServer != null) {
          existingDefaultTagIds = existingServer.defaultTagIds;
          developer.log('Preserving existing defaultTagIds: $existingDefaultTagIds', name: 'ConfigDialog');
        }
      }

      if (!mounted) return;
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      final serverId = _editingServerId ?? ServerConfig.generateId();
      
      developer.log('Creating/updating server with ID: $serverId', name: 'ConfigDialog');
      developer.log('Server name: ${_serverNameController.text.trim()}', name: 'ConfigDialog');
      developer.log('Server URL: $serverUrl', name: 'ConfigDialog');
      developer.log('Auth method: ${_authMethod == _AuthMethod.apiToken ? "API Token" : "Username/Password"}', name: 'ConfigDialog');

      final server = ServerConfig(
        id: serverId,
        name: _serverNameController.text.trim(),
        serverUrl: serverUrl,
        authMethod: _authMethod == _AuthMethod.apiToken
            ? AuthMethod.apiToken
            : AuthMethod.usernamePassword,
        username: _authMethod == _AuthMethod.userPass ? username : null,
        defaultTagIds: existingDefaultTagIds,
        allowSelfSignedCertificates: config.allowSelfSignedCertificates,
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

        developer.log('Selecting server: ${server.id}', name: 'ConfigDialog');
        await serverManager.selectServer(server.id);

        developer.log('Server configuration completed successfully', name: 'ConfigDialog');

        try {
          await Fluttertoast.showToast(
            msg: l10n.connectionSuccess,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
        } catch (e, st) {
          // Some platforms (desktop) or misconfigured runners may not have the
          // fluttertoast plugin registered which throws MissingPluginException.
          // Fallback to a SnackBar so the user still receives feedback.
          developer.log('Fluttertoast unavailable or failed: $e', name: 'ConfigDialog', error: e, stackTrace: st);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.connectionSuccess),
                backgroundColor: Colors.green,
              ),
            );
          }
        }

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
          ConnectionStatus.unknownError => l10n.error_unknown,
          _ => l10n.error_unknown,
        };
        setState(() {
          _inlineConnectionError = err;
        });
      }
    }
  }

  Future<String> _determineProtocol(String serverWithoutProtocol, AppConfigProvider config) async {
    final username = _authMethod == _AuthMethod.userPass ? _usernameController.text.trim() : '';
    final secret = _authMethod == _AuthMethod.userPass ? _passwordController.text : _tokenController.text;
    final useApi = _authMethod == _AuthMethod.apiToken;

    final httpsServer = 'https://$serverWithoutProtocol';
    final httpsService = PaperlessService(
      baseUrl: httpsServer,
      username: username,
      password: useApi ? '' : secret,
      useApiToken: useApi,
      apiToken: useApi ? secret : null,
      allowSelfSignedCertificates: config.allowSelfSignedCertificates,
    );

    final httpsStatus = await httpsService.testConnection();
    
    if (httpsStatus == ConnectionStatus.connected) {
      return httpsServer;
    }

    final httpServer = 'http://$serverWithoutProtocol';
    final httpService = PaperlessService(
      baseUrl: httpServer,
      username: username,
      password: useApi ? '' : secret,
      useApiToken: useApi,
      apiToken: useApi ? secret : null,
      allowSelfSignedCertificates: config.allowSelfSignedCertificates,
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
            Consumer<AppConfigProvider>(
              builder: (context, config, child) {
                return SwitchListTile(
                  title: Text(l10n.allow_self_signed_certificates),
                  value: config.allowSelfSignedCertificates,
                  onChanged: (value) {
                    config.setAllowSelfSignedCertificates(value);
                  },
                );
              },
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