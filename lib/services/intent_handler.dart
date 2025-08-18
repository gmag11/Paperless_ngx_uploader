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

/// Batch event for multiple files received from share intent
class ShareReceivedBatchEvent {
  final List<ShareReceivedEvent> files;

  ShareReceivedBatchEvent({required this.files});

  bool get hasUnsupportedFiles => files.any((f) => !f.supportedType);
  int get totalFiles => files.length;
  int get supportedFilesCount => files.where((f) => f.supportedType).length;
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

  // Broadcast streams for UI to listen for received share events
  static final StreamController<ShareReceivedEvent> _eventController =
      StreamController<ShareReceivedEvent>.broadcast();
  static final StreamController<ShareReceivedBatchEvent> _batchEventController =
      StreamController<ShareReceivedBatchEvent>.broadcast();
  static StreamSubscription<List<SharedMediaFile>>? _mediaSub;

  static Stream<ShareReceivedEvent> get eventStream => _eventController.stream;
  static Stream<ShareReceivedBatchEvent> get batchEventStream => _batchEventController.stream;

  static Future<void> initialize() async {
    developer.log('IntentHandler.initialize: start', name: 'IntentHandler');
    if (!Platform.isAndroid) {
      developer.log('IntentHandler.initialize: not Android, skipping', name: 'IntentHandler');
      return;
    }

    await _handleInitialIntent();

    _mediaSub?.cancel();
    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        developer.log('IntentHandler.getMediaStream: received ${value.length} files', name: 'IntentHandler');
        if (value.isNotEmpty) {
          _handleSharedFiles(value);
        }
      },
      onError: (e, st) {
        developer.log('getMediaStream: error $e',
            name: 'IntentHandler', error: e, stackTrace: st);
      },
    );
    developer.log('IntentHandler.initialize: end', name: 'IntentHandler');
  }

  static Future<void> dispose() async {
    await _mediaSub?.cancel();
    await _eventController.close();
    await _batchEventController.close();
  }

  static Future<void> _handleInitialIntent() async {
    developer.log('IntentHandler._handleInitialIntent: start', name: 'IntentHandler');
    try {
      final sharedFiles =
          await ReceiveSharingIntent.instance.getInitialMedia();
      developer.log('IntentHandler._handleInitialIntent: received ${sharedFiles.length} files', name: 'IntentHandler');
      if (sharedFiles.isNotEmpty) {
        _handleSharedFiles(sharedFiles);
      }
    } catch (e, st) {
      developer.log('Error handling initial intent: $e',
          name: 'IntentHandler._handleInitialIntent',
          error: e,
          stackTrace: st);
    }
    developer.log('IntentHandler._handleInitialIntent: end', name: 'IntentHandler');
  }

  static void _handleSharedFiles(List<SharedMediaFile> files) async {
    developer.log('IntentHandler._handleSharedFiles: start (${files.length} files)', name: 'IntentHandler');
    if (files.isEmpty) {
      developer.log('IntentHandler._handleSharedFiles: no files', name: 'IntentHandler');
      return;
    }

    final events = <ShareReceivedEvent>[];
  // Keep pending events in case UI listeners aren't attached yet (app launched by share)
  // These will be consumed by the UI when it is ready.
  _pendingEvents.clear();
    
    // Process each file to create events
    for (final file in files) {
      final filePath = file.path;
      final fileName = _deriveFileName(file);

      developer.log('IntentHandler._handleSharedFiles: processing file $filePath', name: 'IntentHandler');

      // Best-effort MIME detection: prefer SharedMediaFile type if present, else by extension.
      String? mime = _guessMime(file, filePath);
      // Best-effort size (works for file:// paths)
      int? size;
      try {
        final f = File(filePath);
        developer.log('IntentHandler._handleSharedFiles: checking file exists $filePath', name: 'IntentHandler');
        if (await f.exists()) {
          size = await f.length();
          developer.log('IntentHandler._handleSharedFiles: file exists, size=$size', name: 'IntentHandler');
        } else {
          developer.log('IntentHandler._handleSharedFiles: file does not exist', name: 'IntentHandler');
        }
      } catch (e, st) {
        developer.log('IntentHandler._handleSharedFiles: error accessing file $filePath: $e',
            name: 'IntentHandler', error: e, stackTrace: st);
      }

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

      events.add(event);
  // Store pending event for late listeners (e.g., app started from share intent)
  _pendingEvents.add(event);

      // Emit individual events for backward compatibility
      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
    }

    // Emit batch event for multi-file support
    if (events.isNotEmpty && !_batchEventController.isClosed) {
      _batchEventController.add(ShareReceivedBatchEvent(files: events));
    }
    developer.log('IntentHandler._handleSharedFiles: end', name: 'IntentHandler');
  }

  // Pending events captured during initialization before UI listeners attach
  static final List<ShareReceivedEvent> _pendingEvents = [];

  /// Returns and clears any pending events that were captured before listeners
  /// were attached. This is used by the UI to consume initial share intents.
  static List<ShareReceivedEvent> consumePendingEvents() {
    if (_pendingEvents.isEmpty) {
      developer.log('IntentHandler.consumePendingEvents: no pending events', name: 'IntentHandler');
      return <ShareReceivedEvent>[];
    }
    developer.log('IntentHandler.consumePendingEvents: returning ${_pendingEvents.length} pending events', name: 'IntentHandler');
    final copy = List<ShareReceivedEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    return copy;
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