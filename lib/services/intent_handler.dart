import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Event emitted to UI when a share intent is received.
/// Contains both the resolved file name (for UI) and the file path (for upload).
class ShareReceivedEvent {
  final String fileName;
  final String filePath;

  ShareReceivedEvent({required this.fileName, required this.filePath});
}

class IntentHandler {
  // Broadcast stream for UI to listen for received share events
  static final StreamController<ShareReceivedEvent> _eventController =
      StreamController<ShareReceivedEvent>.broadcast();
  static StreamSubscription<List<SharedMediaFile>>? _mediaSub;

  static Stream<ShareReceivedEvent> get eventStream => _eventController.stream;

  static Future<void> initialize() async {
    // developer.log('initialize: start', name: 'IntentHandler');
    // Guard non-Android platforms
    if (!Platform.isAndroid) {
      // developer.log('initialize: skipped (not Android)', name: 'IntentHandler');
      return;
    }

    // developer.log('initialize: handle initial intent', name: 'IntentHandler');
    // Handle initial intent when app is launched
    await _handleInitialIntent();

    // Listen for sharing intents while app is running
    _mediaSub?.cancel();
    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      // developer.log('getMediaStream: received files=${value.length}', name: 'IntentHandler');
      if (value.isNotEmpty) {
        // developer.log('getMediaStream: handling first file', name: 'IntentHandler');
        _handleSharedFiles(value);
      }
    }, onError: (e, st) {
      developer.log('getMediaStream: error $e',
          name: 'IntentHandler',
          error: e,
          stackTrace: st);
    });
    // developer.log('initialize: media stream subscribed', name: 'IntentHandler');
  }

  static Future<void> dispose() async {
    await _mediaSub?.cancel();
    await _eventController.close();
  }

  static Future<void> _handleInitialIntent() async {
    // developer.log('_handleInitialIntent: start', name: 'IntentHandler');
    try {
      final sharedFiles = await ReceiveSharingIntent.instance.getInitialMedia();
      // developer.log('_handleInitialIntent: files=${sharedFiles.length}', name: 'IntentHandler');
      if (sharedFiles.isNotEmpty) {
        // developer.log('_handleInitialIntent: handling first file', name: 'IntentHandler');
        _handleSharedFiles(sharedFiles);
      }
    } catch (e, st) {
      developer.log('Error handling initial intent: $e',
          name: 'IntentHandler._handleInitialIntent',
          error: e,
          stackTrace: st);
    }
  }

  static void _handleSharedFiles(List<SharedMediaFile> files) {
    // developer.log('_handleSharedFiles: start, files=${files.length}', name: 'IntentHandler');
    if (files.isEmpty) return;

    // For now, handle only the first file
    final file = files.first;
    final filePath = file.path;

    // Derive filename robustly
    final String fileName = _deriveFileName(file);
    // developer.log('_handleSharedFiles: derived filename=$fileName path=$filePath', name: 'IntentHandler');

    // developer.log('_handleSharedFiles: emitting event', name: 'IntentHandler');
    // Notify UI with full event (filename + path)
    if (!_eventController.isClosed) {
      _eventController.add(ShareReceivedEvent(fileName: fileName, filePath: filePath));
      // developer.log('_handleSharedFiles: event emitted', name: 'IntentHandler');
    }
  }

  static String _deriveFileName(SharedMediaFile file) {
    final path = file.path;
    if (path.isNotEmpty) {
      final last = path.split('/').last;
      if (last.trim().isNotEmpty) return last;
    }
    // Fallbacks
    return 'archivo';
  }

  static Future<void> resetIntent() async {
    // developer.log('resetIntent: start', name: 'IntentHandler');
    try {
      await ReceiveSharingIntent.instance.reset();
      // developer.log('resetIntent: done', name: 'IntentHandler');
    } catch (e, st) {
      developer.log('Error resetting intent: $e', name: 'IntentHandler.resetIntent', error: e, stackTrace: st);
    }
  }
}