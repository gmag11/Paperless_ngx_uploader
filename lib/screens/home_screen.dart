import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/ui_helper.dart';
import '../providers/app_config_provider.dart';
import '../providers/server_manager.dart';
import '../widgets/tag_selection_dialog.dart';
import '../widgets/config_dialog.dart';
import '../models/tag.dart';
import '../models/server_config.dart';
import '../services/intent_handler.dart';
import '../services/permission_service.dart';
import '../services/paperless_service.dart';
import '../services/secure_storage_service.dart';
import '../providers/upload_provider.dart';
import '../l10n/gen/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastReceivedFileName;
  StreamSubscription<ShareReceivedEvent>? _intentSub;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      config.loadConfiguration();

      // Check storage permissions on startup
      _checkStoragePermissions();
      
      // Listen for server changes to refresh tags display
      Provider.of<ServerManager>(context, listen: false).addListener(_onServerChanged);
    });

    // Listen for share intent events (filename + file path)
    _intentSub = IntentHandler.eventStream.listen((event) async {
      await _processSharedEvent(event);
    });

    // Also consume any pending events captured during app initialization
    final pending = IntentHandler.consumePendingEvents();
    if (pending.isNotEmpty) {
      developer.log('HomeScreen: Processing ${pending.length} pending events', name: 'HomeScreen');
      for (final ev in pending) {
        // Fire in microtask to avoid reentrancy
        Future.microtask(() => _processSharedEvent(ev));
      }
    }
  }

  Future<void> _processSharedEvent(ShareReceivedEvent event) async {
    developer.log('HomeScreen: Share intent received for file ${event.fileName}', name: 'HomeScreen');
    setState(() {
      _lastReceivedFileName = event.fileName;
    });
    if (!mounted) {
      developer.log('HomeScreen: Widget not mounted after intent', name: 'HomeScreen');
      return;
    }

    // Check storage permissions before proceeding with upload
    developer.log('HomeScreen: Checking storage permissions before upload', name: 'HomeScreen');
    final hasPermission = await PermissionService.checkAndRequestStoragePermissions(context);
    developer.log('HomeScreen: PermissionService.checkAndRequestStoragePermissions returned $hasPermission', name: 'HomeScreen');
    if (!mounted) {
      developer.log('HomeScreen: Widget not mounted after permission check', name: 'HomeScreen');
      return;
    }
    if (!hasPermission) {
      developer.log('HomeScreen: Permissions not granted, aborting upload', name: 'HomeScreen');
      final l10n = AppLocalizations.of(context)!;
      Fluttertoast.showToast(
        msg: l10n.snackbar_upload_error_prefix(l10n.error_permission_denied),
        toastLength: Toast.LENGTH_LONG,
        timeInSecForIosWeb: 5,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    // Inform provider about warning preference (non-blocking)
    final uploadProvider = Provider.of<UploadProvider>(context, listen: false);
    uploadProvider.setIncomingFileWarning(event.showWarning, event.mimeType);

    // Visible notification about the received file
    final receivedMsg = 'Received file: ${event.fileName}';
  UIHelper.showMessage(context, receivedMsg, success: true);

    // Trigger immediate upload without leaving the main screen
    final appConfig = Provider.of<AppConfigProvider>(context, listen: false);

    // Ensure configuration and tags are loaded before using them
    try {
      if (!appConfig.isConfigured) {
        await appConfig.loadConfiguration();
      }
      if (appConfig.selectedTags.isEmpty) {
        await appConfig.loadStoredTags();
      }
    } catch (_) {
      // Ignore loading errors here; upload provider will validate configuration again
    }

    try {
      developer.log('HomeScreen: Permissions granted, proceeding to upload', name: 'HomeScreen');
      final result = await uploadProvider.uploadFile(
        File(event.filePath),
        event.fileName,
      );

      // On success: show confirmation for ~1s then send app to background
      if (!mounted) return;
      if (result.success) {
        final l10n = AppLocalizations.of(context)!;
  UIHelper.showMessage(context, l10n.snackbar_file_uploaded, success: true);
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        // On Android the app was previously sent to background. On desktop, keep app
        // open and reset the provider/UI so the progress indicator and banners are cleared.
        try {
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else {
            uploadProvider.resetUploadState();
            setState(() {
              _lastReceivedFileName = null;
            });
          }
        } catch (_) {
          // If Platform check fails for any reason, fallback to resetting UI.
          uploadProvider.resetUploadState();
          setState(() {
            _lastReceivedFileName = null;
          });
        }
      } else if (uploadProvider.uploadError != null) {
        final l10n = AppLocalizations.of(context)!;
        final localized = _localizeError(l10n, uploadProvider.uploadError!);
  UIHelper.showMessage(context, l10n.snackbar_upload_error_prefix(localized), success: false);
      }
    } catch (e, st) {
      developer.log('HomeScreen: Exception during upload: $e', name: 'HomeScreen', error: e, stackTrace: st);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final localized = _localizeError(l10n, e.toString());
      Fluttertoast.showToast(
        msg: l10n.snackbar_upload_error_prefix(localized),
        toastLength: Toast.LENGTH_LONG,
        timeInSecForIosWeb: 5,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    try {
      Provider.of<ServerManager>(context, listen: false).removeListener(_onServerChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onServerChanged() {
    developer.log('HomeScreen: Server changed, triggering rebuild', name: 'HomeScreen');
    if (mounted) {
      setState(() {});
    }
  }

  // Version checking functionality removed - no longer needed

  /// Checks storage permissions and shows appropriate messages
  Future<void> _checkStoragePermissions() async {
    developer.log('HomeScreen: Checking storage permissions on startup',
        name: 'HomeScreen');
    final hasPermission = await PermissionService.hasStoragePermissions();
    developer.log('HomeScreen: hasStoragePermissions returned $hasPermission',
        name: 'HomeScreen');
    if (!hasPermission) {
      // Don't show dialog on startup, just log it
      // The permission will be requested when user tries to upload
      developer.log(
          'HomeScreen: Storage permissions not granted, will request when needed',
          name: 'HomeScreen');
    }
  }

  // Update notification functionality removed - no longer needed

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Wrap body with DropTarget for desktop platforms (Windows/Linux/macOS)
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appbar_title_home),
      ),
      body: DropTarget(
        onDragEntered: (details) {
          setState(() => _dragging = true);
        },
        onDragExited: (details) {
          setState(() => _dragging = false);
        },
        onDragDone: (details) async {
          setState(() => _dragging = false);
          final paths = details.files.map((f) => f.path).whereType<String>().toList();
          if (paths.isNotEmpty) {
            // Forward to IntentHandler's desktop handler
            await IntentHandler.handleLocalFiles(paths);
          }
        },
        child: Container(
          color: _dragging ? Colors.blue.withValues(alpha: 0.04) : null,
          child: Consumer<AppConfigProvider>(
            builder: (context, config, child) {
              if (!config.isConfigured) {
                return _buildWelcomeScreen(context);
              }

              return _buildMainScreen(context, config);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_upload,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.welcome_title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.welcome_subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showConfigurationDialog(context),
              icon: const Icon(Icons.settings),
              label: Text(l10n.welcome_action_configure_server),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen(BuildContext context, AppConfigProvider config) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Non-blocking type warning banner
            Consumer<UploadProvider>(
              builder: (context, up, _) {
                final l10n = AppLocalizations.of(context)!;
                if (up.showTypeWarning) {
                  final mt = up.lastMimeType ?? '';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.amber),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.banner_type_warning(mt),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (_lastReceivedFileName != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return Text(
                      l10n.snackbar_received_file_prefix(
                          _lastReceivedFileName ?? ''),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
            // Progress indicator card
            Consumer<UploadProvider>(
              builder: (context, up, _) {
                if (!up.isUploading && up.progress == 0.0) {
                  return const SizedBox.shrink();
                }
                final pct =
                    (up.progress * 100).clamp(0, 100).toStringAsFixed(0);
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return Text(
                              l10n.panel_title_uploading_document,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: up.progress > 0.0 && up.progress <= 1.0
                              ? up.progress
                              : null,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return Text(
                              up.bytesTotal > 0
                                  ? l10n.panel_progress_percentage_with_bytes(
                                      pct,
                                      up.bytesSent.toString(),
                                      up.bytesTotal.toString(),
                                    )
                                  : l10n.panel_progress_percentage_only(pct),
                              style: const TextStyle(color: Colors.grey),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            InkWell(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context)!;
                              return Text(
                                l10n.section_title_server_configuration,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context)!;
                              return IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () =>
                                    _showConfigurationDialog(context),
                                tooltip: l10n.tooltip_edit_tags,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          return Text(
                            config.serverUrl ?? l10n.server_not_configured,
                            style: const TextStyle(color: Colors.grey),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tag, color: Colors.blue),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return Text(
                              l10n.section_title_tag_configuration,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showTagSelectionDialog(context),
                              tooltip: l10n.tooltip_edit_tags,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer<ServerManager>(
                      builder: (context, serverManager, child) {
                        final currentServer = serverManager.selectedServer;
                        if (currentServer == null) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                const Icon(Icons.tag_outlined,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final l10n =
                                        AppLocalizations.of(context)!;
                                    return Column(
                                      children: [
                                        Text(
                                          l10n.empty_tags_title,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          l10n.empty_tags_subtitle,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }

                        final selectedTagIds = currentServer.defaultTagIds;
                        developer.log('HomeScreen: Using defaultTagIds from server ${currentServer.id}: $selectedTagIds', name: 'HomeScreen');
                         
                        if (selectedTagIds.isEmpty) {
                          developer.log('HomeScreen: No tags selected for server ${currentServer.id}', name: 'HomeScreen');
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                const Icon(Icons.tag_outlined,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final l10n =
                                        AppLocalizations.of(context)!;
                                    return Column(
                                      children: [
                                        Text(
                                          l10n.empty_tags_title,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          l10n.empty_tags_subtitle,
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }

                        return FutureBuilder<List<Tag>>(
                          key: ValueKey('all_tags_${currentServer.id}'),
                          future: _getTagsForCurrentServer(serverManager, currentServer),
                          builder: (context, tagsSnapshot) {
                            developer.log('HomeScreen: _getTagsForCurrentServer snapshot: ${tagsSnapshot.connectionState}, hasData: ${tagsSnapshot.hasData}, data length: ${tagsSnapshot.data?.length}', name: 'HomeScreen');
                            
                            if (tagsSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            
                            if (tagsSnapshot.hasError) {
                              developer.log('HomeScreen: Error loading tags: ${tagsSnapshot.error}', name: 'HomeScreen');
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: const Text('Error loading tags', style: TextStyle(color: Colors.red)),
                              );
                            }

                            final allTags = tagsSnapshot.data ?? [];
                            final selectedTags = allTags
                                .where((tag) =>
                                    selectedTagIds.contains(tag.id))
                                .toList();
                                  
                            developer.log('HomeScreen: Displaying ${selectedTags.length} tags for server ${currentServer.id}: ${selectedTags.map((t) => t.name).join(', ')}', name: 'HomeScreen');

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final l10n =
                                        AppLocalizations.of(context)!;
                                    return Text(
                                      l10n.tags_configured_count(
                                        selectedTags.length.toString(),
                                        selectedTags.length == 1 ? '' : 's',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: selectedTags.map((tag) {
                                    final colorHex = tag.color ?? '#808080';
                                    final color = Color(
                                      int.parse(colorHex.replaceFirst(
                                          '#', '0xff')),
                                    );
                                    return Chip(
                                      label: Text(
                                        tag.name,
                                        style: TextStyle(
                                          color: _getContrastColor(color),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      backgroundColor: color,
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Text(
                  l10n.howto_title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final l10n = AppLocalizations.of(context)!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.howto_step_1),
                            const SizedBox(height: 8),
                            Text(l10n.howto_step_2),
                            const SizedBox(height: 8),
                            Text(l10n.howto_step_3),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // const Spacer(),
            // SizedBox(
            //   width: double.infinity,
            //   child: OutlinedButton.icon(
            //     onPressed: () => _showConfigurationDialog(context),
            //     icon: const Icon(Icons.edit),
            //     label: const Text('Edit Server Configuration'),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  void _showConfigurationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ConfigDialog(),
    );
  }

  void _showTagSelectionDialog(BuildContext context) async {
    final serverManager = Provider.of<ServerManager>(context, listen: false);
    final currentServer = serverManager.selectedServer;
    
    if (currentServer == null) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
    UIHelper.showMessage(context, l10n.snackbar_configure_server_first, success: false);
      }
      return;
    }

    try {
      final secureStorage = SecureStorageService();
      final password = await secureStorage.getServerCredentials(currentServer.id) ?? '';
      final apiToken = await secureStorage.getServerApiToken(currentServer.id) ?? '';
      
      // Get current selected tags for this server
      final selectedTagIds = currentServer.defaultTagIds;
      final allTags = await _getTagsForCurrentServer(serverManager, currentServer);
      final currentSelectedTags = allTags
          .where((tag) => selectedTagIds.contains(tag.id))
          .toList();

      developer.log('HomeScreen: Showing tag selection dialog for server ${currentServer.id} with ${selectedTagIds.length} selected tags', name: 'HomeScreen');

      if (!mounted) return;

      List<Tag>? result;
      if (context.mounted) {
        result = await showDialog<List<Tag>>(
          context: context,
          builder: (dialogContext) => TagSelectionDialog(
            selectedTags: currentSelectedTags,
            paperlessService: PaperlessService(
              baseUrl: currentServer.serverUrl,
              username: currentServer.username ?? '',
              password: currentServer.authMethod == AuthMethod.usernamePassword ? password : '',
              useApiToken: currentServer.authMethod == AuthMethod.apiToken,
              apiToken: currentServer.authMethod == AuthMethod.apiToken ? apiToken : '',
              allowSelfSignedCertificates: currentServer.allowSelfSignedCertificates,
            ),
            initialSelectedTagIds: selectedTagIds,
            onTagsSelected: (tagIds) async {
              // Update the server's defaultTagIds
              final updatedServer = currentServer.copyWith(defaultTagIds: tagIds);
              await serverManager.updateServer(updatedServer);
              developer.log('HomeScreen: Updated server ${currentServer.id} with ${tagIds.length} default tags', name: 'HomeScreen');
            },
          ),
        );
      }

      if (result != null && mounted) {
        final newSelectedTagIds = result.map((tag) => tag.id).toList();
        final updatedServer = currentServer.copyWith(defaultTagIds: newSelectedTagIds);
        await serverManager.updateServer(updatedServer);
        developer.log('HomeScreen: Updated server ${currentServer.id} with ${newSelectedTagIds.length} default tags after dialog', name: 'HomeScreen');
        
        // Force refresh the UI after tags are updated
        setState(() {});
      }
    } catch (e) {
      developer.log('HomeScreen: Error showing tag selection dialog: $e', name: 'HomeScreen', error: e);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        Fluttertoast.showToast(
          msg: l10n.error_server,
          toastLength: Toast.LENGTH_LONG,
          timeInSecForIosWeb: 5,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }

  Color _getContrastColor(Color color) {
    // Use Flutter's built-in luminance calculation which correctly handles sRGB gamma.
    // This is more reliable than manual linear combinations on raw RGB bytes.
    final luminance = color.computeLuminance();

    // Return black or white depending on the luminance threshold.
    // Threshold 0.5 is a common heuristic for good contrast on most backgrounds.
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Future<List<Tag>> _getTagsForCurrentServer(ServerManager serverManager, ServerConfig currentServer) async {
    try {
      final secureStorage = SecureStorageService();
      final password = await secureStorage.getServerCredentials(currentServer.id) ?? '';
      final apiToken = await secureStorage.getServerApiToken(currentServer.id) ?? '';
      
      final paperlessService = PaperlessService(
        baseUrl: currentServer.serverUrl,
        username: currentServer.username ?? '',
        password: currentServer.authMethod == AuthMethod.usernamePassword ? password : '',
        useApiToken: currentServer.authMethod == AuthMethod.apiToken,
        apiToken: apiToken,
        allowSelfSignedCertificates: currentServer.allowSelfSignedCertificates,
      );
      
      return await paperlessService.fetchTags();
    } catch (e) {
      developer.log('Error creating PaperlessService for server ${currentServer.id}: $e', name: 'HomeScreen');
      return [];
    }
  }

  String _localizeError(AppLocalizations l10n, String codeOrMessage) {
    switch (codeOrMessage) {
      case 'error_auth_failed':
        return l10n.error_auth_failed;
      case 'error_file_too_large':
        return l10n.error_file_too_large;
      case 'error_unsupported_type':
        return l10n.error_unsupported_type;
      case 'error_server':
        return l10n.error_server;
      case 'error_network':
        return l10n.error_network;
      case 'error_file_read':
        return l10n.error_file_read;
      case 'error_invalid_response':
        return l10n.error_invalid_response;
      default:
        // Fallback: if backend already provided a human message, show it.
        return codeOrMessage;
    }
  }

}
