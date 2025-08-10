import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_config_provider.dart';
import '../widgets/tag_selection_dialog.dart';
import '../widgets/config_dialog.dart';
import '../models/tag.dart';
import '../services/intent_handler.dart';
import '../services/version_check_service.dart';
import '../services/permission_service.dart';
import '../providers/upload_provider.dart';
import '../l10n/gen/app_localizations.dart';
// import 'dart:developer' as developer;

class HomeScreen extends StatefulWidget {
  final VersionCheckResult? versionCheckResult;
  
  const HomeScreen({
    super.key,
    this.versionCheckResult,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastReceivedFileName;
  StreamSubscription<ShareReceivedEvent>? _intentSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      config.loadConfiguration();
      
      // Check storage permissions on startup
      _checkStoragePermissions();
      
      // Check for app updates and show notification if available
      _checkForUpdatesAndNotify();
    });

    // Listen for share intent events (filename + file path)
    _intentSub = IntentHandler.eventStream.listen((event) async {
      setState(() {
        _lastReceivedFileName = event.fileName;
      });
      if (!mounted) return;

      // Check storage permissions before proceeding with upload
      final hasPermission = await PermissionService.checkAndRequestStoragePermissions(context);
      if (!mounted) return;
      if (!hasPermission) {
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
      uploadProvider.setIncomingFileWarning(
        showWarning: event.showWarning,
        mimeType: event.mimeType,
      );

      // Visible notification about the received file
      final receivedMsg = 'Received file: ${event.fileName}';
      Fluttertoast.showToast(
        msg: receivedMsg,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 2,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        fontSize: 16.0,
      );

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

      // Read tags at the moment of upload
      final tags = List<Tag>.from(appConfig.selectedTags);

      try {
        await uploadProvider.uploadFile(
          File(event.filePath),
          event.fileName,
          tags,
        );

        // On success: show confirmation for ~1s then send app to background
        if (!mounted) return;
        if (uploadProvider.uploadSuccess) {
          final l10n = AppLocalizations.of(context)!;
          Fluttertoast.showToast(
            msg: l10n.snackbar_file_uploaded,
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 2,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          SystemNavigator.pop();
        } else if (uploadProvider.uploadError != null) {
          final l10n = AppLocalizations.of(context)!;
          final localized = _localizeError(l10n, uploadProvider.uploadError!);
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
      } catch (e) {
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
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  /// Checks for app updates and shows a notification dialog if a new version is available
  void _checkForUpdatesAndNotify() {
    // Use the version check result passed from main.dart
    final versionCheckResult = widget.versionCheckResult;
    
    // Only show notification if:
    // 1. A check was performed (not skipped due to rate limiting)
    // 2. A new version is available
    // 3. We have valid version and URL information
    if (versionCheckResult != null &&
        !versionCheckResult.skipped &&
        versionCheckResult.hasUpdate &&
        versionCheckResult.latestVersion != null &&
        versionCheckResult.releaseUrl != null) {
      
      // Show update notification after a brief delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showUpdateNotification(
            versionCheckResult.latestVersion!,
            versionCheckResult.releaseUrl!,
          );
        }
      });
    }
  }

  /// Checks storage permissions and shows appropriate messages
  Future<void> _checkStoragePermissions() async {
    final hasPermission = await PermissionService.hasStoragePermissions();
    if (!hasPermission) {
      // Don't show dialog on startup, just log it
      // The permission will be requested when user tries to upload
      debugPrint('Storage permissions not granted, will request when needed');
    }
  }

  /// Shows a dialog notifying the user about the available update
  void _showUpdateNotification(String newVersion, String releaseUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text('A new version $newVersion is available.\n\nRelease URL: $releaseUrl'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () async {
                // Close the dialog
                Navigator.of(context).pop();
                
                // Launch the release URL in browser
                final uri = Uri.tryParse(releaseUrl);
                if (uri != null) {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    // Handle launch errors gracefully
                    if (!mounted) return;
                    Fluttertoast.showToast(
                      msg: 'Could not open browser: ${e.toString()}',
                      toastLength: Toast.LENGTH_LONG,
                      timeInSecForIosWeb: 5,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                      fontSize: 16.0,
                    );
                  }
                } else {
                  // Handle invalid URL
                  if (!mounted) return;
                  Fluttertoast.showToast(
                    msg: 'Invalid URL format',
                    toastLength: Toast.LENGTH_LONG,
                    timeInSecForIosWeb: 5,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appbar_title_home),
      ),
      body: Consumer<AppConfigProvider>(
        builder: (context, config, child) {
          if (!config.isConfigured) {
            return _buildWelcomeScreen(context);
          }

          return _buildMainScreen(context, config);
        },
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    l10n.snackbar_received_file_prefix(_lastReceivedFileName ?? ''),
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
              final pct = (up.progress * 100).clamp(0, 100).toStringAsFixed(0);
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: up.progress > 0.0 && up.progress <= 1.0 ? up.progress : null,
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
                              onPressed: () => _showConfigurationDialog(context),
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
                  Consumer<AppConfigProvider>(
                    builder: (context, config, child) {
                      if (config.selectedTags.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            children: [
                              const Icon(Icons.tag_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final l10n = AppLocalizations.of(context)!;
                                  return Column(
                                    children: [
                                      Text(
                                        l10n.empty_tags_title,
                                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                                      ),
                                      Text(
                                        l10n.empty_tags_subtitle,
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final l10n = AppLocalizations.of(context)!;
                              return Text(
                                l10n.tags_configured_count(
                                  config.selectedTags.length.toString(),
                                  config.selectedTags.length == 1 ? '' : 's',
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
                            children: config.selectedTags.map((tag) {
                              final colorHex = tag.color ?? '#808080';
                              final color = Color(
                                int.parse(colorHex.replaceFirst('#', '0xff')),
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
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


  void _showTagSelectionDialog(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    final paperlessService = config.getPaperlessService();
    final currentSelectedTags = List<Tag>.from(config.selectedTags);
    
    if (paperlessService == null) {
      final l10n = AppLocalizations.of(context)!;
      Fluttertoast.showToast(
        msg: l10n.snackbar_configure_server_first,
        toastLength: Toast.LENGTH_LONG,
        timeInSecForIosWeb: 5,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }
    
    showDialog<List<Tag>>(
      context: context,
      builder: (context) => TagSelectionDialog(
        selectedTags: currentSelectedTags,
        configProvider: config,
        paperlessService: paperlessService,
      ),
    ).then((selectedTags) {
      if (selectedTags != null) {
        config.setSelectedTags(selectedTags);
      }
    });
  }

  Color _getContrastColor(Color color) {
    // Use Flutter's built-in luminance calculation which correctly handles sRGB gamma.
    // This is more reliable than manual linear combinations on raw RGB bytes.
    final luminance = color.computeLuminance();

    // Return black or white depending on the luminance threshold.
    // Threshold 0.5 is a common heuristic for good contrast on most backgrounds.
    return luminance > 0.5 ? Colors.black : Colors.white;
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