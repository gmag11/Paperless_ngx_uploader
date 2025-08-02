import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/tag_selection_dialog.dart';
import '../widgets/config_dialog.dart';
import '../models/tag.dart';
import '../models/connection_status.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      config.loadConfiguration();
    });
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
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    
    // Return black or white depending on the luminance
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}