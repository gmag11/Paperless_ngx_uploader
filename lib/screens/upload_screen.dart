import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/tag.dart';
import '../providers/app_config_provider.dart';
import '../providers/upload_provider.dart';

class UploadScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const UploadScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Tag> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _selectedTags.addAll(Provider.of<AppConfigProvider>(context, listen: false).selectedTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<UploadProvider>(
        builder: (context, upload, child) {
          if (upload.uploadSuccess) {
            return _buildUploadSuccess(context);
          }

          return Column(
            children: [
              _buildFilePreview(),
              _buildTagSelection(),
              if (upload.uploadError != null) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    upload.uploadError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: Consumer<UploadProvider>(
        builder: (context, upload, child) {
          return FloatingActionButton.extended(
            onPressed: upload.isUploading
                ? null
                : () => _performUpload(context),
            icon: upload.isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(upload.isUploading ? 'Uploading...' : 'Upload'),
            backgroundColor: upload.uploadSuccess ? Colors.green : null,
          );
        },
      ),
    );
  }

  Widget _buildFilePreview() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.description, size: 48, color: Colors.blue),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Size: ${_getFileSize()}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSelection() {
    return Consumer<AppConfigProvider>(
      builder: (context, config, child) {
        // For now, we'll use the selected tags as available tags
        // In a real app, you would fetch available tags from the server
        final tags = config.selectedTags;
        final filteredTags = tags.where((tag) =>
            tag.name.toLowerCase().contains(_searchController.text.toLowerCase())
        ).toList();

        return Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Tags',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search tags...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                if (tags.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No tags available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = filteredTags[index];
                        final isSelected = _selectedTags.any((t) => t.id == tag.id);
                        
                        return ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  (tag.color ?? '#808080').replaceFirst('#', '0xFF'),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          title: Text(tag.name),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.removeWhere((t) => t.id == tag.id);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedTags.removeWhere((t) => t.id == tag.id);
                              } else {
                                _selectedTags.add(tag);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadSuccess(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload Successful!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.fileName} has been uploaded to Paperless-NGX',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done),
              label: const Text('Done'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileSize() {
    try {
      final file = File(widget.filePath);
      final size = file.lengthSync();
      
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _performUpload(BuildContext context) async {
    final upload = Provider.of<UploadProvider>(context, listen: false);
    final file = File(widget.filePath);
    
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await upload.uploadFile(file, widget.fileName, _selectedTags);
  }
}