import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show File, Platform;

import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Event emitted to UI when a share intent is received.
/// Adds validation info and a warning flag so UI can show a non-blocking banner.
class ShareReceivedEvent {
  final String fileName;
  final String filePath;
  final String? mimeType;
  final int? fileSizeBytes;
  final bool supportedType;
  final bool showWarning;

  ShareReceivedEvent({
    required this.fileName,
    required this.filePath,
    this.mimeType,
    this.fileSizeBytes,
    required this.supportedType,
    required this.showWarning,
  });
}

class IntentHandler {
  // Supported MIME types and common extensions
  static final Map<String, List<String>> _supportedTypes = {
    'application/pdf': ['.pdf'],
    'image/jpeg': ['.jpg', '.jpeg'],
    'image/png': ['.png'],
    'image/tiff': ['.tif', '.tiff'],
    'image/gif': ['.gif'],
    'image/webp': ['.webp'],
  };

  // Broadcast stream for UI to listen for received share events
  static final StreamController<ShareReceivedEvent> _eventController =
      StreamController<ShareReceivedEvent>.broadcast();
  static StreamSubscription<List<SharedMediaFile>>? _mediaSub;

  static Stream<ShareReceivedEvent> get eventStream => _eventController.stream;

  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    await _handleInitialIntent();

    _mediaSub?.cancel();
    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleSharedFiles(value);
        }
      },
      onError: (e, st) {
        developer.log('getMediaStream: error $e',
            name: 'IntentHandler', error: e, stackTrace: st);
      },
    );
  }

  static Future<void> dispose() async {
    await _mediaSub?.cancel();
    await _eventController.close();
  }

  static Future<void> _handleInitialIntent() async {
    try {
      final sharedFiles =
          await ReceiveSharingIntent.instance.getInitialMedia();
      if (sharedFiles.isNotEmpty) {
        _handleSharedFiles(sharedFiles);
      }
    } catch (e, st) {
      developer.log('Error handling initial intent: $e',
          name: 'IntentHandler._handleInitialIntent',
          error: e,
          stackTrace: st);
    }
  }

  static void _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final file = files.first;
    final filePath = file.path;
    final fileName = _deriveFileName(file);

    // Best-effort MIME detection: prefer SharedMediaFile type if present, else by extension.
    String? mime = _guessMime(file, filePath);
    // Best-effort size (works for file:// paths)
    int? size;
    try {
      final f = File(filePath);
      if (await f.exists()) {
        size = await f.length();
      }
    } catch (_) {}

    final supported = _isSupported(mime, fileName);
    final showWarning = !supported; // per product decision, warn but proceed

    final event = ShareReceivedEvent(
      fileName: fileName,
      filePath: filePath,
      mimeType: mime,
      fileSizeBytes: size,
      supportedType: supported,
      showWarning: showWarning,
    );

    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  static bool _isSupported(String? mime, String fileName) {
    if (mime != null && _supportedTypes.containsKey(mime)) return true;
    final ext = p.extension(fileName).toLowerCase();
    for (final exts in _supportedTypes.values) {
      if (exts.contains(ext)) return true;
    }
    return false;
  }

  static String? _guessMime(SharedMediaFile file, String filePath) {
    // SharedMediaFile has a type parameter on some platforms; use path as fallback
    final ext = p.extension(filePath).toLowerCase();
    for (final entry in _supportedTypes.entries) {
      if (entry.value.contains(ext)) return entry.key;
    }
    // leave null to indicate unknown; server may still accept
    return null;
  }

  static String _deriveFileName(SharedMediaFile file) {
    final path = file.path;
    if (path.isNotEmpty) {
      final last = path.split('/').last;
      if (last.trim().isNotEmpty) return last;
    }
    return 'archivo';
  }

  static Future<void> resetIntent() async {
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (e, st) {
      developer.log('Error resetting intent: $e',
          name: 'IntentHandler.resetIntent', error: e, stackTrace: st);
    }
  }
}