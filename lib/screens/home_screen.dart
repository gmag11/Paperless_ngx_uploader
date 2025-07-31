import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/tag_selection_dialog.dart';
import '../models/tag.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasShownTagDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = Provider.of<AppConfigProvider>(context, listen: false);
      config.loadConfiguration().then((_) {
        if (config.isConfigured && !_hasShownTagDialog) {
          _showTagSelectionDialog(context);
        }
      });
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
    return Padding(
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
                      const Icon(Icons.cloud_done, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Server Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (config.isConnecting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.serverUrl ?? 'Not configured',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (config.connectionError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      config.connectionError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (config.isConnected) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Connected successfully',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
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
                  Text('3. Choose tags and upload'),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showConfigurationDialog(context),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Server Configuration'),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfigurationDialog(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    final serverUrlController = TextEditingController(text: config.serverUrl);
    final usernameController = TextEditingController(text: config.username);
    final passwordController = TextEditingController(text: config.password);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://paperless.example.com',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          Consumer<AppConfigProvider>(
            builder: (context, config, child) {
              return ElevatedButton(
                onPressed: config.isConnecting
                    ? null
                    : () async {
                        final serverUrl = serverUrlController.text.trim();
                        final username = usernameController.text.trim();
                        final password = passwordController.text.trim();

                        if (serverUrl.isEmpty || username.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        await config.saveConfiguration(serverUrl, username, password);
                        await config.testConnection();
                        
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                child: config.isConnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save & Test'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTagSelectionDialog(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    
    // Mock tags list
    final mockTags = [
      Tag(id: 1, name: 'Important', color: '#FF0000'),
      Tag(id: 2, name: 'Work', color: '#0000FF'),
      Tag(id: 3, name: 'Personal', color: '#00FF00'),
      Tag(id: 4, name: 'Bills', color: '#FFA500'),
      Tag(id: 5, name: 'Receipts', color: '#800080'),
      Tag(id: 6, name: 'Tax', color: '#008080'),
      Tag(id: 7, name: 'Medical', color: '#FFC0CB'),
      Tag(id: 8, name: 'Insurance', color: '#A52A2A'),
    ];
    
    // Default tags (empty for now)
    final defaultTags = <Tag>[];
    
    showDialog<List<Tag>>(
      context: context,
      builder: (context) => TagSelectionDialog(
        tags: mockTags,
        selectedTags: config.selectedTags,
        defaultTags: defaultTags,
      ),
    ).then((selectedTags) {
      if (selectedTags != null) {
        config.setSelectedTags(selectedTags);
      }
      setState(() {
        _hasShownTagDialog = true;
      });
    });
  }

  Color _getContrastColor(Color color) {
    // Calculate the perceptive luminance (human eye favors green color)
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    
    // Return black or white depending on the luminance
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}