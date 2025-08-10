import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/tag.dart';
import '../models/upload_result.dart';
import '../services/paperless_service.dart' as paperless;
import 'app_config_provider.dart';

typedef TranslateCallback = String Function(String key);

class UploadProvider extends ChangeNotifier {
  final AppConfigProvider _appConfig;
  final TranslateCallback translate;

  UploadProvider({
    required AppConfigProvider appConfigProvider,
    TranslateCallback? translate,
  }) : _appConfig = appConfigProvider,
       translate = translate ?? ((key) => key); // Default to returning the key unchanged

  bool _isUploading = false;
  String? _uploadError;
  bool _uploadSuccess = false;

  // Progress state (0.0..1.0) and last raw counters
  double _progress = 0.0;
  int _bytesSent = 0;
  int _bytesTotal = 0;

  // Debounced progress notification control
  // Only emit notifyListeners when integer percent changes or after debounce
  static const Duration _progressDebounce = Duration(milliseconds: 100);
  Timer? _progressDebounceTimer;
  int _lastEmittedPercent = -1;

  // Last warning from intent (non-blocking)
  bool _showTypeWarning = false;
  String? _lastMimeType;

  // Multi-file upload state
  List<UploadResult> _uploadResults = [];
  int _currentFileIndex = 0;
  int _totalFiles = 0;

  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;
  bool get uploadSuccess => _uploadSuccess;
  double get progress => _progress;
  int get bytesSent => _bytesSent;
  int get bytesTotal => _bytesTotal;
  bool get showTypeWarning => _showTypeWarning;
  String? get lastMimeType => _lastMimeType;
  
  // Multi-file upload getters
  List<UploadResult> get uploadResults => _uploadResults;
  int get currentFileIndex => _currentFileIndex;
  int get totalFiles => _totalFiles;
  bool get isMultiFileUpload => _totalFiles > 1;

  // Allow UI to set warning flag from intent event
  void setIncomingFileWarning({required bool showWarning, String? mimeType}) {
    _showTypeWarning = showWarning;
    _lastMimeType = mimeType;
    notifyListeners();
  }

  Future<void> uploadFile(File file, String filename, List<Tag> selectedTags) async {
    await uploadMultipleFiles([file], [filename], selectedTags);
  }

  Future<void> uploadMultipleFiles(
    List<File> files,
    List<String> filenames,
    List<Tag> selectedTags,
  ) async {
    if (files.isEmpty || filenames.isEmpty || files.length != filenames.length) {
      _uploadError = translate('error_invalid_files');
      _uploadSuccess = false;
      notifyListeners();
      return;
    }

    _isUploading = true;
    _uploadError = null;
    _uploadSuccess = false;
    _progress = 0.0;
    _bytesSent = 0;
    _bytesTotal = 0;
    _lastEmittedPercent = -1;
    _uploadResults = [];
    _currentFileIndex = 0;
    _totalFiles = files.length;
    _cancelProgressDebounce();
    notifyListeners();

    try {
      final service = _resolvePaperlessService();
      if (service == null) {
        _uploadError = translate('snackbar_configure_server_first');
        _uploadSuccess = false;
        return;
      }

      final tagIds = selectedTags.map((tag) => tag.id).toList();
      final results = <UploadResult>[];

      // Process files sequentially to maintain progress tracking
      for (int i = 0; i < files.length; i++) {
        _currentFileIndex = i + 1; // 1-based indexing for UI
        
        final file = files[i];
        final filename = filenames[i];
        
        String? title;
        final dot = filename.lastIndexOf('.');
        if (dot > 0) {
          title = filename.substring(0, dot);
        } else {
          title = filename.isNotEmpty ? filename : null;
        }

        try {
          final result = await service.uploadDocument(
            filePath: file.path,
            fileName: filename,
            title: title,
            tagIds: tagIds,
            onProgress: (sent, total) {
              // Calculate overall progress across all files
              final previousFilesProgress = (i * 1.0) / files.length;
              final currentFileProgress = total > 0 ? (sent / total) / files.length : 0.0;
              _progress = previousFilesProgress + currentFileProgress;
              
              _bytesSent = sent;
              _bytesTotal = total;
              _maybeNotifyProgress();
            },
          );

          results.add(UploadResult(
            success: result.success,
            error: result.success ? null : _mapErrorForUi(result.message, result.errorCode),
            filename: filename,
            errorCode: result.errorCode,
          ));

        } catch (e) {
          developer.log(
            'Upload response: status=error, file=$filename, error=$e',
            name: 'UploadProvider.uploadMultipleFiles',
            error: e,
          );
          results.add(UploadResult(
            success: false,
            error: e.toString(),
            filename: filename,
          ));
        }
      }

      _uploadResults = results;
      _uploadSuccess = results.every((r) => r.success);
      
      if (!_uploadSuccess) {
        // Collect all error messages
        final failedUploads = results.where((r) => !r.success).toList();
        if (failedUploads.length == 1) {
          _uploadError = failedUploads.first.error;
        } else {
          _uploadError = translate('error_multiple_files_failed')
              .replaceAll('{count}', failedUploads.length.toString());
        }
      } else {
        _uploadError = null;
      }
      
      _progress = 1.0;
      _maybeNotifyProgress(forceEmit: true);

    } catch (e) {
      developer.log(
        'Upload response: status=error, error=$e',
        name: 'UploadProvider.uploadMultipleFiles',
        error: e,
      );
      _uploadError = e.toString();
      _uploadSuccess = false;
    } finally {
      _isUploading = false;
      _cancelProgressDebounce();
      notifyListeners();
    }
  }

  // Emit progress updates efficiently
  void _maybeNotifyProgress({bool forceEmit = false}) {
    final percent = (_progress.isNaN || _progress.isInfinite) ? 0.0 : _progress.clamp(0.0, 1.0);
    final currentInt = (percent * 100).floor();

    // If integer percent changed, emit immediately
    if (forceEmit || currentInt != _lastEmittedPercent) {
      _lastEmittedPercent = currentInt;
      _cancelProgressDebounce();
      notifyListeners();
      return;
    }

    // Otherwise, debounce updates
    if (_progressDebounceTimer == null || !_progressDebounceTimer!.isActive) {
      _progressDebounceTimer = Timer(_progressDebounce, () {
        // Do not change _lastEmittedPercent here; this is a soft refresh
        notifyListeners();
      });
    }
  }

  void _cancelProgressDebounce() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = null;
  }

  String _mapErrorForUi(String message, String? code) {
    switch (code) {
      case 'AUTH_ERROR':
        return translate('error_auth_failed');
      case 'FILE_TOO_LARGE':
        return translate('error_file_too_large');
      case 'UNSUPPORTED_TYPE':
        return translate('error_unsupported_type');
      case 'SERVER_ERROR':
        return translate('error_server');
      case 'NETWORK_ERROR':
        return translate('error_network');
      case 'FILE_ERROR':
        return translate('error_file_read');
      case 'BAD_RESPONSE':
        return translate('error_invalid_response');
      default:
        return message;
    }
  }

  // Resolve a configured PaperlessService via AppConfigProvider, if available.
  paperless.PaperlessService? _resolvePaperlessService() {
    final svc = _appConfig.getPaperlessService();
    if (svc == null) {
      developer.log('AppConfigProvider returned null PaperlessService (not configured)',
          name: 'UploadProvider._resolvePaperlessService');
      return null;
    }
    return svc;
  }

  void resetUploadState() {
    _uploadError = null;
    _uploadSuccess = false;
    _isUploading = false;
    _progress = 0.0;
    _bytesSent = 0;
    _bytesTotal = 0;
    _showTypeWarning = false;
    _lastMimeType = null;
    _lastEmittedPercent = -1;
    _uploadResults = [];
    _currentFileIndex = 0;
    _totalFiles = 0;
    _cancelProgressDebounce();
    notifyListeners();
  }
}