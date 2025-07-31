import 'package:flutter/material.dart';
import 'dart:io';

class UploadProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _tags = [];
  List<int> _selectedTagIds = [];
  bool _isLoadingTags = false;
  String? _tagsError;
  bool _isUploading = false;
  String? _uploadError;
  bool _uploadSuccess = false;

  List<Map<String, dynamic>> get tags => _tags;
  List<int> get selectedTagIds => _selectedTagIds;
  bool get isLoadingTags => _isLoadingTags;
  String? get tagsError => _tagsError;
  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;
  bool get uploadSuccess => _uploadSuccess;

  Future<void> fetchTags() async {
    _isLoadingTags = true;
    _tagsError = null;
    notifyListeners();

    try {
      // TODO: Implement actual tag fetching from Paperless-NGX
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock data for now
      _tags = [
        {'id': 1, 'name': 'Invoice', 'color': '#FF6B6B'},
        {'id': 2, 'name': 'Receipt', 'color': '#4ECDC4'},
        {'id': 3, 'name': 'Contract', 'color': '#45B7D1'},
        {'id': 4, 'name': 'Tax', 'color': '#96CEB4'},
        {'id': 5, 'name': 'Personal', 'color': '#FECA57'},
      ];
    } catch (e) {
      _tagsError = e.toString();
      _tags = [];
    } finally {
      _isLoadingTags = false;
      notifyListeners();
    }
  }

  void toggleTagSelection(int tagId) {
    if (_selectedTagIds.contains(tagId)) {
      _selectedTagIds.remove(tagId);
    } else {
      _selectedTagIds.add(tagId);
    }
    notifyListeners();
  }

  void setSelectedTags(List<int> tagIds) {
    _selectedTagIds = List.from(tagIds);
    notifyListeners();
  }

  Future<void> uploadFile(File file, String filename) async {
    _isUploading = true;
    _uploadError = null;
    _uploadSuccess = false;
    notifyListeners();

    try {
      // TODO: Implement actual file upload
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock success
      _uploadSuccess = true;
    } catch (e) {
      _uploadError = e.toString();
      _uploadSuccess = false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  void resetUploadState() {
    _uploadError = null;
    _uploadSuccess = false;
    _isUploading = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> searchTags(String query) {
    if (query.isEmpty) return _tags;
    
    return _tags.where((tag) => 
      tag['name'].toString().toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
}