import 'package:flutter/material.dart';
import 'package:paperless_ngx_android_uploader/models/tag.dart';

class TagSelectionDialog extends StatefulWidget {
  final List<Tag> tags;
  final List<Tag> selectedTags;
  final List<Tag> defaultTags;

  const TagSelectionDialog({
    super.key,
    required this.tags,
    required this.selectedTags,
    required this.defaultTags,
  });

  @override
  State<TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<TagSelectionDialog> {
  late List<Tag> _selectedTags;
  late List<Tag> _filteredTags;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize selected tags from widget's selectedTags
    _selectedTags = widget.selectedTags.map((tag) {
      // Try to find matching tag in the main tags list to preserve all properties
      return widget.tags.firstWhere(
        (t) => t.id == tag.id,
        orElse: () => tag,
      );
    }).toList();

    // Initialize filtered tags with all available tags
    _filteredTags = List.from(widget.tags);
    
    // Ensure filtered tags include any selected tags not in the main list
    for (final tag in _selectedTags) {
      if (!_filteredTags.any((t) => t.id == tag.id)) {
        _filteredTags.add(tag);
      }
    }
    
    _searchController.addListener(_filterTags);
  }

  void _filterTags() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      // Start with original tags list
      List<Tag> newFilteredTags = widget.tags.where((tag) {
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
    });
  }

  void _toggleTag(Tag tag) {
    setState(() {
      if (_selectedTags.any((t) => t.id == tag.id)) {
        _selectedTags.removeWhere((t) => t.id == tag.id);
      } else {
        // Find the existing tag from the original selectedTags list if available
        final existingTag = widget.selectedTags.firstWhere(
          (t) => t.id == tag.id,
          orElse: () => tag,
        );
        _selectedTags.add(existingTag);
      }
    });
  }

  void _selectDefaults() {
    setState(() {
      _selectedTags.clear();
      for (final defaultTag in widget.defaultTags) {
        // Find matching tag from the original list to preserve properties
        final matchingTag = widget.tags.firstWhere(
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