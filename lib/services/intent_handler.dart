import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show File, Platform;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

// For desktop file drag-and-drop we will accept plain file paths and reuse
// the same processing pipeline as the share intent. This keeps behavior
// consistent across platforms.

/// Event emitted to UI when a share intent is received.
/// Adds validation info and a warning flag so UI can show a non-blocking banner.
class ShareReceivedEvent {
  final String fileName;
  final String filePath;
  final String? mimeType;
  final int? fileSizeBytes;
  final bool supportedType;
  final bool showWarning;
  /// True when [filePath] is an http/https URL rather than a local file path.
  final bool isUrl;

  ShareReceivedEvent({
    required this.fileName,
    required this.filePath,
    this.mimeType,
    this.fileSizeBytes,
    required this.supportedType,
    required this.showWarning,
    this.isUrl = false,
  });
}

/// Payload delivered by the native side for a share or "open with" intent:
/// the local paths that could be read, plus the display names of the files that
/// could not be read.
class SharePayload {
  final List<String> files;
  final List<String> errors;

  SharePayload({required this.files, this.errors = const <String>[]});

  bool get isEmpty => files.isEmpty && errors.isEmpty;
}

/// Batch event for multiple files received from share intent
class ShareReceivedBatchEvent {
  final List<ShareReceivedEvent> files;

  /// Display names of the files the native side could not read. They are not
  /// uploaded, so the UI must report them instead of pretending they arrived.
  final List<String> errors;

  ShareReceivedBatchEvent({required this.files, this.errors = const <String>[]});

  bool get hasUnsupportedFiles => files.any((f) => !f.supportedType);
  bool get hasErrors => errors.isNotEmpty;
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

  static const _methodChannel = MethodChannel('net.gmartin.paperlessngx_uploader/share');
  static const _eventChannel = EventChannel('net.gmartin.paperlessngx_uploader/share_stream');

  // Broadcast streams for UI to listen for received share events
  static final StreamController<ShareReceivedEvent> _eventController =
      StreamController<ShareReceivedEvent>.broadcast();
  static final StreamController<ShareReceivedBatchEvent> _batchEventController =
      StreamController<ShareReceivedBatchEvent>.broadcast();
  static StreamSubscription<dynamic>? _streamSub;

  static Stream<ShareReceivedEvent> get eventStream => _eventController.stream;
  static Stream<ShareReceivedBatchEvent> get batchEventStream => _batchEventController.stream;

  static Future<void> initialize() async {
    developer.log('IntentHandler.initialize: start', name: 'IntentHandler');
    if (!Platform.isAndroid) {
      developer.log('IntentHandler.initialize: not Android, skipping', name: 'IntentHandler');
      return;
    }

    await _handleInitialIntent();

    _streamSub?.cancel();
    _streamSub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        final payload = parseSharePayload(data);
        developer.log(
          'IntentHandler.eventChannel: received ${payload.files.length} files, '
          '${payload.errors.length} errors',
          name: 'IntentHandler');
        if (!payload.isEmpty) {
          handleSharePayload(payload);
        }
      },
      onError: (e, st) {
        developer.log('eventChannel: error $e',
            name: 'IntentHandler', error: e, stackTrace: st);
      },
    );
    developer.log('IntentHandler.initialize: end', name: 'IntentHandler');
  }

  static Future<void> dispose() async {
    await _streamSub?.cancel();
    await _eventController.close();
    await _batchEventController.close();
  }

  /// Parses the value delivered by the native side. Accepts the `{files, errors}`
  /// map and the legacy plain list of paths.
  static SharePayload parseSharePayload(dynamic data) {
    if (data is Map) {
      final files = (data['files'] as List?)?.cast<String>() ?? const <String>[];
      final errors = (data['errors'] as List?)?.cast<String>() ?? const <String>[];
      return SharePayload(files: files, errors: errors);
    }
    if (data is List) {
      return SharePayload(files: data.cast<String>());
    }
    return SharePayload(files: const <String>[]);
  }

  static Future<void> _handleInitialIntent() async {
    developer.log('IntentHandler._handleInitialIntent: start', name: 'IntentHandler');
    try {
      final result = await _methodChannel.invokeMethod<dynamic>('getInitialSharedFiles');
      final payload = parseSharePayload(result);
      developer.log(
        'IntentHandler._handleInitialIntent: received ${payload.files.length} files, '
        '${payload.errors.length} errors',
        name: 'IntentHandler');
      if (!payload.isEmpty) {
        await handleSharePayload(payload);
      }
    } catch (e, st) {
      developer.log('Error handling initial intent: $e',
          name: 'IntentHandler._handleInitialIntent',
          error: e,
          stackTrace: st);
    }
    developer.log('IntentHandler._handleInitialIntent: end', name: 'IntentHandler');
  }

  // Pending events captured during initialization before UI listeners attach
  static final List<ShareReceivedEvent> _pendingEvents = [];
  static final List<String> _pendingErrors = [];

  /// Returns and clears the pending batch (events and the names of the files that
  /// could not be read) captured before listeners were attached. This is used by
  /// the UI to consume initial share intents.
  static ShareReceivedBatchEvent consumePendingBatch() {
    if (_pendingEvents.isEmpty && _pendingErrors.isEmpty) {
      developer.log('IntentHandler.consumePendingBatch: no pending events', name: 'IntentHandler');
      return ShareReceivedBatchEvent(files: const <ShareReceivedEvent>[]);
    }
    developer.log(
      'IntentHandler.consumePendingBatch: returning ${_pendingEvents.length} pending events '
      'and ${_pendingErrors.length} errors',
      name: 'IntentHandler');
    final batch = ShareReceivedBatchEvent(
      files: List<ShareReceivedEvent>.from(_pendingEvents),
      errors: List<String>.from(_pendingErrors),
    );
    _pendingEvents.clear();
    _pendingErrors.clear();
    return batch;
  }

  static bool _isSupported(String? mime, String fileName) {
    if (mime != null && _supportedTypes.containsKey(mime)) return true;
    final ext = p.extension(fileName).toLowerCase();
    for (final exts in _supportedTypes.values) {
      if (exts.contains(ext)) return true;
    }
    return false;
  }

  static Future<void> resetIntent() async {
    try {
      await _methodChannel.invokeMethod<void>('reset');
    } catch (e, st) {
      developer.log('Error resetting intent: $e',
          name: 'IntentHandler.resetIntent', error: e, stackTrace: st);
    }
  }

  /// Public helper for desktop platforms: accept a list of local file paths
  /// (from drag-and-drop) and process them like a share intent.
  ///
  /// This method is safe to call from Windows/Linux/macOS where
  /// `ReceiveSharingIntent` is not available.
  static Future<void> handleLocalFiles(List<String> filePaths) async {
    developer.log('IntentHandler.handleLocalFiles: start (${filePaths.length} files)', name: 'IntentHandler');
    if (filePaths.isEmpty) return;

    try {
      await handleSharePayload(SharePayload(files: filePaths));
    } catch (e, st) {
      developer.log('IntentHandler.handleLocalFiles: error $e', name: 'IntentHandler', error: e, stackTrace: st);
    }
    developer.log('IntentHandler.handleLocalFiles: end', name: 'IntentHandler');
  }

  /// Processes a payload coming from the native side (share intent or "open
  /// with") or from desktop drag-and-drop, and emits the batch event with the
  /// files that could not be read so the UI can report them.
  static Future<void> handleSharePayload(SharePayload payload) async {
    developer.log(
      'IntentHandler.handleSharePayload: start (${payload.files.length} files, '
      '${payload.errors.length} errors)',
      name: 'IntentHandler');
    if (payload.isEmpty) return;

    final events = <ShareReceivedEvent>[];

    // Pending events bridge the window before the UI attaches its batch
    // listener. When a listener is already attached (warm start), the batch is
    // delivered through the stream and must not be kept as pending, or a later
    // State recreation would consume and process the same files twice.
    final hasBatchListener = _batchEventController.hasListener;

    // Clear pending events if any (app launched by drag-drop or share)
    _pendingEvents.clear();
    _pendingErrors.clear();

    final paths = payload.files;

    for (final filePath in paths) {
      developer.log('IntentHandler.handleSharePayload: processing file $filePath', name: 'IntentHandler');

      ShareReceivedEvent event;

      if (_isUrl(filePath)) {
        // Shared as a URL (e.g. from a browser)
        final fileName = _fileNameFromUrl(filePath);
        developer.log('IntentHandler.handleSharePayload: detected URL, derived name=$fileName', name: 'IntentHandler');
        final supported = p.extension(fileName).toLowerCase() == '.pdf' || fileName == 'document.pdf';
        event = ShareReceivedEvent(
          fileName: fileName,
          filePath: filePath,
          mimeType: 'application/pdf',
          fileSizeBytes: null,
          supportedType: supported,
          showWarning: false,
          isUrl: true,
        );
      } else {
        // Regular file path (already resolved by native code)
        final fileName = filePath.split(RegExp(r'[\\/]+')).last;
        String? mime = _guessMimeFromPath(filePath);
        int? size;
        try {
          final f = File(filePath);
          if (await f.exists()) {
            size = await f.length();
          }
        } catch (e, st) {
          developer.log('IntentHandler.handleSharePayload: error accessing file $filePath: $e', name: 'IntentHandler', error: e, stackTrace: st);
        }

        final supported = _isSupported(mime, fileName);
        event = ShareReceivedEvent(
          fileName: fileName,
          filePath: filePath,
          mimeType: mime,
          fileSizeBytes: size,
          supportedType: supported,
          showWarning: !supported,
        );
      }

      events.add(event);
      if (!hasBatchListener) {
        _pendingEvents.add(event);
      }

      if (!_eventController.isClosed) {
        _eventController.add(event);
      }
    }

    // The files that could not be read are carried through the batch so the UI
    // reports them instead of pretending they arrived.
    if (!hasBatchListener) {
      _pendingErrors.addAll(payload.errors);
    }

    if ((events.isNotEmpty || payload.errors.isNotEmpty) &&
        !_batchEventController.isClosed) {
      _batchEventController.add(
        ShareReceivedBatchEvent(files: events, errors: payload.errors),
      );
    }

    developer.log('IntentHandler.handleSharePayload: end', name: 'IntentHandler');
  }

  static String? _guessMimeFromPath(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    for (final entry in _supportedTypes.entries) {
      if (entry.value.contains(ext)) return entry.key;
    }
    return null;
  }

  /// Returns true if [path] is an http/https URL.
  static bool _isUrl(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Derives a file name from a URL.
  /// Strips query parameters and fragments, then takes the last path segment.
  /// Falls back to 'document.pdf' if nothing useful is found.
  static String _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final last = Uri.decodeComponent(segments.last);
        if (last.isNotEmpty) {
          // Ensure it has a file extension; if not, append .pdf
          return p.extension(last).isEmpty ? '$last.pdf' : last;
        }
      }
    } catch (_) {}
    return 'document.pdf';
  }
}