import 'package:flutter/material.dart';
import 'dart:io';
import '../models/tag.dart';

class UploadProvider extends ChangeNotifier {
  bool _isUploading = false;
  String? _uploadError;
  bool _uploadSuccess = false;

  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;
  bool get uploadSuccess => _uploadSuccess;

  Future<void> uploadFile(File file, String filename, List<Tag> selectedTags) async {
    _isUploading = true;
    _uploadError = null;
    _uploadSuccess = false;
    notifyListeners();

    try {
      // Extract tag IDs from selected tags
      final tagIds = selectedTags.map((tag) => tag.id).toList();
      
      // TODO: Implement actual file upload with tags
      // The upload should include tagIds in the request
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
}