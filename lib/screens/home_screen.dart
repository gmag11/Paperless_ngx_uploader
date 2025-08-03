import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/tag_selection_dialog.dart';
import '../widgets/config_dialog.dart';
import '../models/tag.dart';
import '../services/intent_handler.dart';
import '../providers/upload_provider.dart';
// import 'dart:developer' as developer;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    });

    // Listen for share intent events (filename + file path)
    _intentSub = IntentHandler.eventStream.listen((event) async {
      setState(() {
        _lastReceivedFileName = event.fileName;
      });
      if (!mounted) return;

      // Inform provider about warning preference (non-blocking)
      final uploadProvider = Provider.of<UploadProvider>(context, listen: false);
      uploadProvider.setIncomingFileWarning(
        showWarning: event.showWarning,
        mimeType: event.mimeType,
      );

      // Visible notification about the received file
      final receivedMsg = 'Received file: ${event.fileName}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(receivedMsg)),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subida correcta'), duration: Duration(milliseconds: 800)),
          );
          await Future.delayed(const Duration(milliseconds: 1000));
          if (!mounted) return;
          SystemNavigator.pop();
        } else if (uploadProvider.uploadError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(uploadProvider.uploadError!), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paperless-NGX Uploader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showConfigurationDialog(context),
          ),
        ],
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
            const Text(
              'Welcome to Paperless-NGX Uploader',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Configure your Paperless-NGX server to start uploading documents',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showConfigurationDialog(context),
              icon: const Icon(Icons.settings),
              label: const Text('Configure Server'),
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
              if (up.showTypeWarning) {
                final mt = up.lastMimeType ?? 'desconocido';
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tipo de archivo $mt puede no estar soportado. Se intentará subir igualmente.',
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
                color: Colors.green.withOpacity(0.15),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Received file: $_lastReceivedFileName',
                style: const TextStyle(fontWeight: FontWeight.w600),
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
                      const Text(
                        'Uploading document',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: up.progress > 0.0 && up.progress <= 1.0 ? up.progress : null,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        up.bytesTotal > 0
                            ? '$pct% (${up.bytesSent}/${up.bytesTotal} bytes)'
                            : '$pct%',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Server Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.serverUrl ?? 'Not configured',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
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
                      const Text(
                        'Global Tag Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showTagSelectionDialog(context),
                        tooltip: 'Edit tags',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Consumer<AppConfigProvider>(
                    builder: (context, config, child) {
                      if (config.selectedTags.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const Column(
                            children: [
                              Icon(Icons.tag_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'No tags selected',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              Text(
                                'Tap "Select Tags" to configure',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${config.selectedTags.length} tag${config.selectedTags.length == 1 ? '' : 's'} configured',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: config.selectedTags.map((tag) {
                              final colorHex = tag.color ?? '#808080';
                              final color = Color(
                                int.parse(colorHex.replaceFirst('#', '0xFF')),
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
          const Text(
            'How to use:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Share a document from any app'),
                  SizedBox(height: 8),
                  Text('2. Select "Paperless-NGX Uploader"'),
                  SizedBox(height: 8),
                  Text('3. Upload will happen inmediately'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure server connection first')),
      );
      return;
    }
    
    showDialog<List<Tag>>(
      context: context,
      builder: (context) => TagSelectionDialog(
        selectedTags: currentSelectedTags,
        defaultTags: const [], // Empty for now, will be implemented later
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
    // Calculate the perceptive luminance (human eye favors green color)
    final luminance = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b) / 255;
    
    // Return black or white depending on the luminance
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}