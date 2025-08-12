import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:paperlessngx_uploader/services/secure_storage_service.dart';
import 'package:paperlessngx_uploader/models/connection_status.dart';
import 'package:paperlessngx_uploader/providers/app_config_provider.dart';
import 'package:paperlessngx_uploader/l10n/gen/app_localizations.dart';
import 'package:paperlessngx_uploader/services/paperless_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  // Obfuscation flags
  bool _obscurePassword = true;
  bool _obscureToken = true;

  // Track if current secret values were loaded from storage (not being configured now)
  bool _passwordLoadedFromStorage = false;
  bool _tokenLoadedFromStorage = false;

  // Local transient error to display under fields without altering provider persistence
  String? _inlineConnectionError;

  // Local connecting flag for the button spinner during pre-save test
  bool? _localConnecting = false;

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
  
      // Load secrets but mark them as loaded-from-storage so they cannot be revealed
      final loadedPassword = credentials['password'] ?? '';
      final loadedToken = credentials['apiToken'] ?? '';
      _passwordController.text = loadedPassword;
      _tokenController.text = loadedToken;
  
      _passwordLoadedFromStorage = loadedPassword.isNotEmpty;
      _tokenLoadedFromStorage = loadedToken.isNotEmpty;
  
      // Always start obscured when loading from storage
      _obscurePassword = true;
      _obscureToken = true;
  
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
  
    // Attach listeners to detect when user starts configuring new secrets
    _passwordController.addListener(() {
      // If user edits the field in this session, allow reveal
      if (_passwordLoadedFromStorage && _passwordController.text != (credentials['password'] ?? '')) {
        setState(() {
          _passwordLoadedFromStorage = false;
          _obscurePassword = true; // keep obscured even after transition
        });
      }
    });
    _tokenController.addListener(() {
      if (_tokenLoadedFromStorage && _tokenController.text != (credentials['apiToken'] ?? '')) {
        setState(() {
          _tokenLoadedFromStorage = false;
          _obscureToken = true;
        });
      }
    });
  }

  Future<void> _saveAndTestConnection() async {
    final l10n = AppLocalizations.of(context)!;
    // Clear inline error on new attempt
    if (mounted) {
      setState(() {
        _inlineConnectionError = null;
      });
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Also ignore any existing provider error to avoid duplicate display this attempt;
    // the Consumer prefers _inlineConnectionError over provider error.

    final config = Provider.of<AppConfigProvider>(context, listen: false);

    final server = _serverUrlController.text.trim();
    final username = _authMethod == _AuthMethod.userPass ? _usernameController.text.trim() : '';
    final secret = _authMethod == _AuthMethod.userPass ? _passwordController.text : _tokenController.text;

    // Persist NOTHING until test passes. Test against a temporary PaperlessService instance.
    final useApi = _authMethod == _AuthMethod.apiToken;
    final tempService = PaperlessService(
      baseUrl: server,
      username: username,
      password: useApi ? '' : secret,
      useApiToken: useApi,
      apiToken: useApi ? secret : null,
      allowSelfSignedCertificates: config.allowSelfSignedCertificates,
    );

    // Perform test
    final status = await tempService.testConnection();
    // Reset any previous provider error so we don't show stale messages under the fields
    if (mounted) {
      // No public API to clear error immediately; rely on local inline error for this attempt
      setState(() {
        _inlineConnectionError = null;
      });
    }

    // If successful, persist and close; otherwise show inline error (red text under fields).
    if (mounted && status == ConnectionStatus.connected) {
      if (_authMethod == _AuthMethod.userPass) {
        await config.saveConfiguration(server, username, secret);
      } else {
        await config.saveConfiguration(server, '', secret);
      }
      // Avoid a second verification request; we already know it's connected.
      if (!mounted) return;

      // Show green toast with white text (no auto-close of dialog beyond existing behavior)
      Fluttertoast.showToast(
        msg: l10n.connectionSuccess,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Navigator.of(context).pop(true);
    } else {
      // Map status to inline error to render in red text area (like original UI)
      final isTokenMode = _authMethod == _AuthMethod.apiToken;
      // Already have l10n from method start
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
      if (mounted) {
        setState(() {
          _inlineConnectionError = err;
        });
      }
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
                    // When switching modes, keep secrets obscured
                    _obscurePassword = true;
                    _obscureToken = true;
                  });
                },
              ),
              const SizedBox(height: 8),

              // Conditional fields
              if (_authMethod == _AuthMethod.userPass) ...[
                // If there is an inline error while in userPass mode, ensure it's shown below these fields
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
                  // Bind obscureText to runtime flag so reveal works when allowed
                  obscureText: _passwordLoadedFromStorage ? true : _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  onTap: () {
                    // If current value was loaded from storage, clear to start new configuration
                    if (_passwordLoadedFromStorage) {
                      setState(() {
                        _passwordController.clear();
                        _passwordLoadedFromStorage = false; // now user is configuring
                        _obscurePassword = true; // keep hidden initially
                      });
                    }
                  },
                  onChanged: (_) {
                    // Ensure reveal icon becomes active if user starts typing after a programmatic clear
                    if (_passwordLoadedFromStorage) {
                      setState(() {
                        _passwordLoadedFromStorage = false;
                        _obscurePassword = true;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.field_label_password,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: _passwordLoadedFromStorage
                        ? Tooltip(
                            message: l10n.field_label_password,
                            child: IconButton(
                              icon: const Icon(Icons.visibility_off),
                              onPressed: null, // disabled; cannot reveal loaded secret
                            ),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: (_) {
                              setState(() {
                                _obscurePassword = false;
                              });
                            },
                            onLongPressEnd: (_) {
                              setState(() {
                                _obscurePassword = true;
                              });
                            },
                            child: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                // Toggle for accessibility
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                  ),
                  validator: (value) {
                    if (_authMethod == _AuthMethod.userPass) {
                      if (value == null || value.isEmpty) {
                        return l10n.validation_enter_password;
                      }
                    }
                    return null;
                  },
                ),
              ] else ...[
                // If there is an inline error while in token mode, ensure it's shown below these fields
                TextFormField(
                  controller: _tokenController,
                  // Bind obscureText to runtime flag so reveal works when allowed
                  obscureText: _tokenLoadedFromStorage ? true : _obscureToken,
                  enableSuggestions: false,
                  autocorrect: false,
                  onTap: () {
                    // If current value was loaded from storage, clear to start new configuration
                    if (_tokenLoadedFromStorage) {
                      setState(() {
                        _tokenController.clear();
                        _tokenLoadedFromStorage = false; // now user is configuring
                        _obscureToken = true; // keep hidden initially
                      });
                    }
                  },
                  onChanged: (_) {
                    if (_tokenLoadedFromStorage) {
                      setState(() {
                        _tokenLoadedFromStorage = false;
                        _obscureToken = true;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.field_label_api_token,
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: _tokenLoadedFromStorage
                        ? Tooltip(
                            message: l10n.field_label_api_token,
                            child: IconButton(
                              icon: const Icon(Icons.visibility_off),
                              onPressed: null, // disabled; cannot reveal loaded secret
                            ),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: (_) {
                              setState(() {
                                _obscureToken = false;
                              });
                            },
                            onLongPressEnd: (_) {
                              setState(() {
                                _obscureToken = true;
                              });
                            },
                            child: IconButton(
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
                // Note: Per-field inline error widgets removed to prevent duplication.
              ],

              Consumer<AppConfigProvider>(
                builder: (context, config, child) {
                  return SwitchListTile(
                    title: Text(l10n.allow_self_signed_certificates),
                    subtitle: Text(l10n.allow_self_signed_certificates_description),
                    value: config.allowSelfSignedCertificates,
                    onChanged: (value) {
                      config.setAllowSelfSignedCertificates(value);
                    },
                  );
                },
              ),
              Consumer<AppConfigProvider>(
                builder: (context, config, child) {
                  // Show only ONE error: prefer inline error when present (pre-save test),
                  // otherwise fall back to provider error.
                  final errorText = _inlineConnectionError ?? config.connectionError;
                  if (errorText != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        errorText,
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
            // Use local transient connecting state for the pre-save test to prevent the spinner from sticking.
            final bool isConnecting = _localConnecting ?? false;

            return ElevatedButton(
              onPressed: isConnecting
                  ? null
                  : () async {
                      setState(() {
                        // mark local connecting
                        _localConnecting = true;
                        // Always re-obscure before attempting
                        _obscurePassword = true;
                        _obscureToken = true;
                        // clear inline error for a new attempt
                        _inlineConnectionError = null;
                      });
                      try {
                        await _saveAndTestConnection();
                      } finally {
                        if (mounted) {
                          setState(() {
                            _localConnecting = false;
                          });
                        }
                      }
                    },
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