import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/tag.dart';
import '../services/paperless_service.dart';
import 'app_config_provider.dart';

class UploadProvider extends ChangeNotifier {
  final AppConfigProvider _appConfig;

  UploadProvider({required AppConfigProvider appConfigProvider})
      : _appConfig = appConfigProvider;

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

  bool get isUploading => _isUploading;
  String? get uploadError => _uploadError;
  bool get uploadSuccess => _uploadSuccess;
  double get progress => _progress;
  int get bytesSent => _bytesSent;
  int get bytesTotal => _bytesTotal;
  bool get showTypeWarning => _showTypeWarning;
  String? get lastMimeType => _lastMimeType;

  // Allow UI to set warning flag from intent event
  void setIncomingFileWarning({required bool showWarning, String? mimeType}) {
    _showTypeWarning = showWarning;
    _lastMimeType = mimeType;
    notifyListeners();
  }

  Future<void> uploadFile(File file, String filename, List<Tag> selectedTags) async {
    _isUploading = true;
    _uploadError = null;
    _uploadSuccess = false;
    _progress = 0.0;
    _bytesSent = 0;
    _bytesTotal = 0;
    _lastEmittedPercent = -1;
    _cancelProgressDebounce();
    notifyListeners();

    try {
      final tagIds = selectedTags.map((tag) => tag.id).toList();

      String? title;
      final dot = filename.lastIndexOf('.');
      if (dot > 0) {
        title = filename.substring(0, dot);
      } else {
        title = filename.isNotEmpty ? filename : null;
      }

      final service = _resolvePaperlessService();

      if (service == null) {
        _uploadError = 'Please configure server connection first';
        _uploadSuccess = false;
        return;
      }

      final result = await service.uploadDocument(
        filePath: file.path,
        fileName: filename,
        title: title,
        tagIds: tagIds,
        onProgress: (sent, total) {
          _bytesSent = sent;
          _bytesTotal = total <= 0 ? _bytesTotal : total;
          if (total > 0) {
            _progress = sent / total;
          } else {
            _progress = 0.0;
          }
          _maybeNotifyProgress();
        },
      );

      if (result.success) {
        _uploadSuccess = true;
        _uploadError = null;
        _progress = 1.0;
        // Ensure final 100% is emitted
        _maybeNotifyProgress(forceEmit: true);
      } else {
        _uploadSuccess = false;
        _uploadError = _mapErrorForUi(result.message, result.errorCode);
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
        return 'Autenticación fallida. Revisa usuario y contraseña.';
      case 'FILE_TOO_LARGE':
        return 'El archivo es demasiado grande para el servidor.';
      case 'UNSUPPORTED_TYPE':
        return 'Tipo de archivo no soportado por el servidor.';
      case 'SERVER_ERROR':
        return 'Error del servidor. Inténtalo más tarde.';
      case 'NETWORK_ERROR':
        return 'Error de red. Revisa tu conexión.';
      case 'FILE_ERROR':
        return 'Error leyendo el archivo local.';
      case 'BAD_RESPONSE':
        return 'Respuesta no válida del servidor.';
      default:
        return message;
    }
  }

  // Resolve a configured PaperlessService via AppConfigProvider, if available.
  PaperlessService? _resolvePaperlessService() {
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
    _cancelProgressDebounce();
    notifyListeners();
  }
}