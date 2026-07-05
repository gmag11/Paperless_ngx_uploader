import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart' as dio;
import 'package:path_provider/path_provider.dart';
import '../services/paperless_service.dart' as paperless;
import '../providers/app_config_provider.dart';

typedef StringCallback = String Function(String key);

class UploadProvider extends ChangeNotifier {
  final AppConfigProvider appConfigProvider;
  final StringCallback translate;

  UploadProvider({
    required this.appConfigProvider,
    required this.translate,
  });

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  double _progress = 0.0;
  double get progress => _progress;

  int _bytesSent = 0;
  int get bytesSent => _bytesSent;

  int _bytesTotal = 0;
  int get bytesTotal => _bytesTotal;

  String? _uploadError;
  String? get uploadError => _uploadError;

  bool _showTypeWarning = false;
  bool get showTypeWarning => _showTypeWarning;

  String? _lastMimeType;
  String? get lastMimeType => _lastMimeType;

  void setIncomingFileWarning(bool show, String? mimeType) {
    _showTypeWarning = show;
    _lastMimeType = mimeType;
    notifyListeners();
  }

  Future<paperless.UploadResult> uploadFile(File file, String fileName, {List<int>? tagIds}) async {
    if (_isUploading) {
      return paperless.UploadResult.error(
        'Upload already in progress',
        'UPLOAD_IN_PROGRESS',
      );
    }

    _isUploading = true;
    _progress = 0.0;
    _bytesSent = 0;
    _bytesTotal = 0;
    _uploadError = null;
    notifyListeners();

    try {
      // Check if server is configured
      if (!appConfigProvider.isConfigured) {
        _isUploading = false;
        notifyListeners();
        return paperless.UploadResult.error(
          translate('snackbar_configure_server_first'),
          'NOT_CONFIGURED',
        );
      }

      // Get Paperless service
      final service = await appConfigProvider.getPaperlessService();
      if (service == null) {
        _isUploading = false;
        notifyListeners();
        return paperless.UploadResult.error(
          translate('error_auth_failed'),
          'AUTH_FAILED',
        );
      }

      // Debug: log the target server and auth mode before uploading
      try {
        final authSummary = service.useApiToken ? 'API token' : 'Basic';
        developer.log('UploadProvider: Uploading to ${service.baseUrl} using $authSummary', name: 'UploadProvider');
      } catch (_) {}

      // Get selected tags (use provided tags if passed, otherwise defaults)
      final selectedTagIds = tagIds ?? await appConfigProvider.getSelectedTags();
      
      // Upload the file
      final result = await service.uploadDocument(
        filePath: file.path,
        fileName: fileName,
        tagIds: selectedTagIds,
        onProgress: (sent, total) {
          _bytesSent = sent;
          _bytesTotal = total;
          _progress = total > 0 ? sent / total : 0.0;
          notifyListeners();
        },
      );

      _isUploading = false;
      notifyListeners();
      
      return result;
    } catch (e) {
      _isUploading = false;
      _uploadError = e.toString();
      notifyListeners();
      
      String errorMessage;
      String errorCode;
      
      if (e.toString().contains('401') || e.toString().contains('403')) {
        errorMessage = translate('error_auth_failed');
        errorCode = 'AUTH_ERROR';
      } else if (e.toString().contains('Network') || e.toString().contains('SocketException')) {
        errorMessage = translate('error_network');
        errorCode = 'NETWORK_ERROR';
      } else if (e.toString().contains('FileSystemException')) {
        errorMessage = translate('error_file_read');
        errorCode = 'FILE_ERROR';
      } else if (e.toString().contains('413')) {
        errorMessage = translate('error_file_too_large');
        errorCode = 'FILE_TOO_LARGE';
      } else if (e.toString().contains('415')) {
        errorMessage = translate('error_unsupported_type');
        errorCode = 'UNSUPPORTED_TYPE';
      } else {
        errorMessage = translate('error_server');
        errorCode = 'SERVER_ERROR';
      }

      return paperless.UploadResult.error(errorMessage, errorCode);
    }
  }

  void resetUploadState() {
    _isUploading = false;
    _progress = 0.0;
    _bytesSent = 0;
    _bytesTotal = 0;
    _uploadError = null;
    _showTypeWarning = false;
    _lastMimeType = null;
    notifyListeners();
  }

  /// Downloads a remote URL to a temporary file, then uploads it to Paperless.
  /// The temporary file is deleted after the upload completes (success or error).
  Future<paperless.UploadResult> uploadUrl(String url, String fileName, {List<int>? tagIds}) async {
    if (_isUploading) {
      return paperless.UploadResult.error(
        'Upload already in progress',
        'UPLOAD_IN_PROGRESS',
      );
    }

    _isUploading = true;
    _progress = 0.0;
    _bytesSent = 0;
    _bytesTotal = 0;
    _uploadError = null;
    notifyListeners();

    File? tempFile;
    try {
      if (!appConfigProvider.isConfigured) {
        _isUploading = false;
        notifyListeners();
        return paperless.UploadResult.error(
          translate('snackbar_configure_server_first'),
          'NOT_CONFIGURED',
        );
      }

      final service = await appConfigProvider.getPaperlessService();
      if (service == null) {
        _isUploading = false;
        notifyListeners();
        return paperless.UploadResult.error(
          translate('error_auth_failed'),
          'AUTH_FAILED',
        );
      }

      // --- Download to temp file ---
      developer.log('UploadProvider.uploadUrl: downloading $url', name: 'UploadProvider');
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/$fileName');

      final downloader = dio.Dio();
      await downloader.download(
        url,
        tempFile.path,
        onReceiveProgress: (received, total) {
          // Show download progress in the first half (0..0.5)
          if (total > 0) {
            _bytesSent = received;
            _bytesTotal = total;
            _progress = (received / total) * 0.5;
            notifyListeners();
          }
        },
        options: dio.Options(
          receiveTimeout: const Duration(minutes: 5),
          followRedirects: true,
          maxRedirects: 5,
        ),
      );
      developer.log('UploadProvider.uploadUrl: download complete, size=${await tempFile.length()}', name: 'UploadProvider');

      // --- Upload to Paperless ---
      final selectedTagIds = tagIds ?? await appConfigProvider.getSelectedTags();
      final result = await service.uploadDocument(
        filePath: tempFile.path,
        fileName: fileName,
        tagIds: selectedTagIds,
        onProgress: (sent, total) {
          // Upload progress in the second half (0.5..1.0)
          _bytesSent = sent;
          _bytesTotal = total;
          _progress = 0.5 + (total > 0 ? sent / total : 0.0) * 0.5;
          notifyListeners();
        },
      );

      _isUploading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isUploading = false;
      _uploadError = e.toString();
      notifyListeners();
      developer.log('UploadProvider.uploadUrl: error $e', name: 'UploadProvider');
      return paperless.UploadResult.error(
        translate('error_network'),
        'DOWNLOAD_ERROR',
      );
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
          developer.log('UploadProvider.uploadUrl: temp file deleted', name: 'UploadProvider');
        }
      } catch (_) {}
    }
  }
}