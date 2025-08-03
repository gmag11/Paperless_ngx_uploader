import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../models/tag.dart';
import '../services/paperless_service.dart';
import 'package:provider/provider.dart';
import 'app_config_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UploadProvider extends ChangeNotifier {
  // Static reference to AppConfigProvider to avoid changing public APIs or requiring BuildContext here.
  // Wire this once at app startup (e.g., after creating providers).
  static AppConfigProvider? _appConfig;
  static void setAppConfigProvider(AppConfigProvider appConfigProvider) {
    _appConfig = appConfigProvider;
  }

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
      // Extract tag IDs from selected tags (array of integers as per OpenAPI "tags" items: integer)
      final tagIds = selectedTags.map((tag) => tag.id).toList();

      // Optional "title" field per OpenAPI; derive from filename without extension
      String? title;
      final dot = filename.lastIndexOf('.');
      if (dot > 0) {
        title = filename.substring(0, dot);
      } else {
        title = filename.isNotEmpty ? filename : null;
      }

      // Logging per requirement
      developer.log(
        'Uploading file to Paperless-NGX: filename=$filename, tags=$tagIds',
        name: 'UploadProvider.uploadFile',
      );

      // Delegate to PaperlessService which applies:
      // - Endpoint: POST {baseUrl}/api/documents/post_document/
      // - Security: Authorization Basic header via constructor-derived credentials
      // - multipart/form-data with fields:
      //   - "document": binary file (required)
      //   - "title": optional string
      //   - "tags": array of integers (OpenAPI: items integer, writeOnly)
      PaperlessService? service = _resolvePaperlessService();

      // Fallback: if AppConfigProvider is not wired, try secure storage directly (no API changes elsewhere)
      if (service == null) {
        try {
          const storage = FlutterSecureStorage();
          final serverUrl = await storage.read(key: 'server_url');
          final username = await storage.read(key: 'username');
          final password = await storage.read(key: 'password');

          if (serverUrl != null && username != null && password != null) {
            service = PaperlessService(
              baseUrl: serverUrl,
              username: username,
              password: password,
            );
            developer.log(
              'Resolved PaperlessService from secure storage with baseUrl=$serverUrl',
              name: 'UploadProvider.uploadFile',
            );
          }
        } catch (e) {
          developer.log(
            'Error reading configuration from secure storage: $e',
            name: 'UploadProvider.uploadFile',
            error: e,
          );
        }
      }

      if (service == null) {
        _uploadError = 'Please configure server connection first';
        developer.log(
          'Paperless service not configured. Missing server credentials.',
          name: 'UploadProvider.uploadFile',
        );
        _uploadSuccess = false;
        return;
      } else {
        developer.log(
          'Resolved PaperlessService with baseUrl=${service.baseUrl}',
          name: 'UploadProvider.uploadFile',
        );
      }

      final result = await service.uploadDocument(
        filePath: file.path,
        fileName: filename,
        title: title,
        tagIds: tagIds,
      );

      developer.log(
        'Upload response: status=${result.success ? 200 : 400}',
        name: 'UploadProvider.uploadFile',
      );

      if (result.success) {
        _uploadSuccess = true;
        _uploadError = null;
      } else {
        _uploadSuccess = false;
        _uploadError = result.message;
      }
    } catch (e) {
      developer.log(
        'Upload response: status=error, error=$e',
        name: 'UploadProvider.uploadFile',
        error: e,
      );
      _uploadError = e.toString();
      _uploadSuccess = false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // Resolve a configured PaperlessService via AppConfigProvider, if available.
  PaperlessService? _resolvePaperlessService() {
    final cfg = _appConfig;
    if (cfg == null) {
      developer.log('AppConfigProvider not set on UploadProvider', name: 'UploadProvider._resolvePaperlessService');
      return null;
    }
    final svc = cfg.getPaperlessService();
    if (svc == null) {
      developer.log('AppConfigProvider returned null PaperlessService (not configured)', name: 'UploadProvider._resolvePaperlessService');
      return null;
    }
    return svc;
  }

  void resetUploadState() {
    _uploadError = null;
    _uploadSuccess = false;
    _isUploading = false;
    notifyListeners();
  }
}