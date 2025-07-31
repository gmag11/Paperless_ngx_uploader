import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class IntentHandler {
  static const _channel = MethodChannel('paperless_ngx_android_uploader/intent');

  static Future<void> initialize() async {
    // Handle initial intent when app is launched
    await _handleInitialIntent();
    
    // Listen for sharing intents while app is running
    ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedFiles(value);
      }
    });
  }

  static Future<void> _handleInitialIntent() async {
    try {
      final sharedFiles = await ReceiveSharingIntent.instance.getInitialMedia();
      if (sharedFiles.isNotEmpty) {
        _handleSharedFiles(sharedFiles);
      }
    } catch (e) {
      print('Error handling initial intent: $e');
    }
  }

  static void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // For now, handle only the first file
    final file = files.first;
    final filePath = file.path;
    final fileName = filePath.split('/').last;

    // Navigate to upload screen
    _navigateToUploadScreen(filePath, fileName);
  }

  static void _navigateToUploadScreen(String filePath, String fileName) {
    _channel.invokeMethod('navigateToUpload', {
      'filePath': filePath,
      'fileName': fileName,
    });
  }

  static Future<void> resetIntent() async {
    await ReceiveSharingIntent.instance.reset();
  }
}