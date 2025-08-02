import 'package:flutter/material.dart';
import 'package:paperless_ngx_android_uploader/models/tag.dart';
import 'package:paperless_ngx_android_uploader/providers/app_config_provider.dart';
import 'package:paperless_ngx_android_uploader/services/paperless_service.dart';

class TagSelectionDialog extends StatefulWidget {
  final List<Tag> selectedTags;
  final List<Tag> defaultTags;
  final AppConfigProvider configProvider;
  final PaperlessService paperlessService;

  const TagSelectionDialog({
    super.key,
    required this.selectedTags,
    required this.defaultTags,
    required this.configProvider,
    required this.paperlessService,
  });

  @override
  State<TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<TagSelectionDialog> {
  late List<Tag> _selectedTags;
  late List<Tag> _filteredTags;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<Tag> _allTags = [];

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.selectedTags);
    _filteredTags = [];
    _searchController.addListener(_filterTags);
    _fetchTags();
  }

  Future<void> _fetchTags() async {
    try {
      final tags = await widget.paperlessService.fetchTags();
      setState(() {
        _allTags = tags;
        _updateFilteredTags();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tags: $e';
        _isLoading = false;
      });
    }
  }

  void _filterTags() {
    setState(() {
      _updateFilteredTags();
    });
  }

  void _updateFilteredTags() {
    final query = _searchController.text.toLowerCase();
    // Start with original tags list
    List<Tag> newFilteredTags = _allTags.where((tag) {
      return tag.name.toLowerCase().contains(query);
    }).toList();
    
    // Add any selected tags that match the search but aren't in the main list
    for (final selectedTag in _selectedTags) {
      if (selectedTag.name.toLowerCase().contains(query) &&
          !newFilteredTags.any((t) => t.id == selectedTag.id)) {
        newFilteredTags.add(selectedTag);
      }
    }
    
    _filteredTags = newFilteredTags;
  }

  void _toggleTag(Tag tag) {
    setState(() {
      if (_selectedTags.any((t) => t.id == tag.id)) {
        _selectedTags.removeWhere((t) => t.id == tag.id);
        widget.configProvider.removeSelectedTag(tag);
      } else {
        // Find the existing tag from the original selectedTags list if available
        final existingTag = widget.selectedTags.firstWhere(
          (t) => t.id == tag.id,
          orElse: () => tag,
        );
        _selectedTags.add(existingTag);
        widget.configProvider.addSelectedTag(existingTag);
      }
    });
  }

  void _selectDefaults() {
    setState(() {
      _selectedTags.clear();
      for (final defaultTag in widget.defaultTags) {
        // Find matching tag from the original list to preserve properties
        final matchingTag = _allTags.firstWhere(
          (t) => t.id == defaultTag.id,
          orElse: () => defaultTag,
        );
        _selectedTags.add(matchingTag);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AlertDialog(
        title: const Text('Select Tags'),
        content: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(_error!),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
                _isLoading = true;
              });
              _fetchTags();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Select Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search tags',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _selectDefaults,
              child: const Text('Select Default Tags'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredTags.length,
                itemBuilder: (context, index) {
                  final tag = _filteredTags[index];
                  final isSelected = _selectedTags.any((t) => t.id == tag.id);
                  
                  return ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (value) => _toggleTag(tag),
                    ),
                    title: Text(tag.name),
                    subtitle: tag.color != null
                        ? Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _parseColor(tag.color!),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('#${tag.color!}'),
                            ],
                          )
                        : null,
                    onTap: () => _toggleTag(tag),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedTags),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}