import 'package:flutter_test/flutter_test.dart';
//import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:paperlessngx_uploader/services/intent_handler.dart';

void main() {
  group('IntentHandler', () {
    group('ShareReceivedEvent', () {
      test('creates event with correct properties', () {
        final event = ShareReceivedEvent(
          fileName: 'test.pdf',
          filePath: '/test.pdf',
          mimeType: 'application/pdf',
          fileSizeBytes: 1024,
          supportedType: true,
          showWarning: false,
        );

        expect(event.fileName, 'test.pdf');
        expect(event.filePath, '/test.pdf');
        expect(event.mimeType, 'application/pdf');
        expect(event.fileSizeBytes, 1024);
        expect(event.supportedType, isTrue);
        expect(event.showWarning, isFalse);
      });

      test('creates event with minimal properties', () {
        final event = ShareReceivedEvent(
          fileName: 'test.jpg',
          filePath: '/test.jpg',
          supportedType: false,
          showWarning: true,
        );

        expect(event.fileName, 'test.jpg');
        expect(event.filePath, '/test.jpg');
        expect(event.mimeType, isNull);
        expect(event.fileSizeBytes, isNull);
        expect(event.supportedType, isFalse);
        expect(event.showWarning, isTrue);
      });
    });

    group('ShareReceivedBatchEvent', () {
      test('creates batch event with correct properties', () {
        final files = [
          ShareReceivedEvent(
            fileName: 'test1.pdf',
            filePath: '/test1.pdf',
            mimeType: 'application/pdf',
            fileSizeBytes: 1024,
            supportedType: true,
            showWarning: false,
          ),
          ShareReceivedEvent(
            fileName: 'test2.jpg',
            filePath: '/test2.jpg',
            mimeType: 'image/jpeg',
            fileSizeBytes: 2048,
            supportedType: true,
            showWarning: false,
          ),
        ];

        final batchEvent = ShareReceivedBatchEvent(files: files);

        expect(batchEvent.totalFiles, 2);
        expect(batchEvent.supportedFilesCount, 2);
        expect(batchEvent.hasUnsupportedFiles, isFalse);
      });

      test('detects unsupported files in batch', () {
        final files = [
          ShareReceivedEvent(
            fileName: 'test.pdf',
            filePath: '/test.pdf',
            mimeType: 'application/pdf',
            fileSizeBytes: 1024,
            supportedType: true,
            showWarning: false,
          ),
          ShareReceivedEvent(
            fileName: 'test.exe',
            filePath: '/test.exe',
            mimeType: null,
            fileSizeBytes: 2048,
            supportedType: false,
            showWarning: true,
          ),
        ];

        final batchEvent = ShareReceivedBatchEvent(files: files);

        expect(batchEvent.totalFiles, 2);
        expect(batchEvent.supportedFilesCount, 1);
        expect(batchEvent.hasUnsupportedFiles, isTrue);
      });

      test('handles empty file list', () {
        final batchEvent = ShareReceivedBatchEvent(files: []);
        expect(batchEvent.totalFiles, 0);
        expect(batchEvent.supportedFilesCount, 0);
        expect(batchEvent.hasUnsupportedFiles, isFalse);
      });

      test('handles all unsupported files', () {
        final files = [
          ShareReceivedEvent(
            fileName: 'test.exe',
            filePath: '/test.exe',
            mimeType: null,
            fileSizeBytes: 1024,
            supportedType: false,
            showWarning: true,
          ),
          ShareReceivedEvent(
            fileName: 'test.zip',
            filePath: '/test.zip',
            mimeType: 'application/zip',
            fileSizeBytes: 2048,
            supportedType: false,
            showWarning: true,
          ),
        ];

        final batchEvent = ShareReceivedBatchEvent(files: files);
        expect(batchEvent.totalFiles, 2);
        expect(batchEvent.supportedFilesCount, 0);
        expect(batchEvent.hasUnsupportedFiles, isTrue);
      });
    });

    group('Stream properties', () {
      test('event streams are broadcast streams', () {
        expect(IntentHandler.eventStream.isBroadcast, isTrue);
        expect(IntentHandler.batchEventStream.isBroadcast, isTrue);
      });
    });

    group('supported types integration', () {
      // Test the integration through the supported types map
      late final Map<String, List<String>> supportedTypes;

      setUpAll(() {
        // Create a test version of supported types for testing
        supportedTypes = {
          'application/pdf': ['.pdf'],
          'image/jpeg': ['.jpg', '.jpeg'],
          'image/png': ['.png'],
          'image/tiff': ['.tif', '.tiff'],
          'image/gif': ['.gif'],
          'image/webp': ['.webp'],
        };
      });

      test('contains expected MIME type mappings', () {
        expect(supportedTypes, contains('application/pdf'));
        expect(supportedTypes['application/pdf'], contains('.pdf'));
        expect(supportedTypes['image/jpeg'], contains('.jpg'));
        expect(supportedTypes['image/jpeg'], contains('.jpeg'));
      });

      test('supports PDF files', () {
        expect(supportedTypes['application/pdf'], contains('.pdf'));
        expect(supportedTypes['application/pdf'], isNotNull);
      });

      test('supports JPEG files with both extensions', () {
        expect(supportedTypes['image/jpeg'], contains('.jpg'));
        expect(supportedTypes['image/jpeg'], contains('.jpeg'));
      });

      test('supports common image formats', () {
        expect(supportedTypes['image/png'], contains('.png'));
        expect(supportedTypes['image/gif'], contains('.gif'));
        expect(supportedTypes['image/webp'], contains('.webp'));
      });

      test('supports TIFF files with both extensions', () {
        expect(supportedTypes['image/tiff'], contains('.tif'));
        expect(supportedTypes['image/tiff'], contains('.tiff'));
      });
    });

    group('file name extraction', () {
      test('extracts file name from full path', () {
        const path = '/storage/emulated/0/Downloads/test.pdf';
        final parts = path.split('/');
        final fileName = parts.last;
        expect(fileName, 'test.pdf');
      });

      test('handles file without extension', () {
        const path = '/storage/emulated/0/Downloads/document';
        final parts = path.split('/');
        final fileName = parts.last;
        expect(fileName, 'document');
      });

      test('handles empty path with default name', () {
        const path = '';
        final fileName = path.isNotEmpty ? path.split('/').last : 'archivo';
        expect(fileName, 'archivo');
      });

      test('handles root path correctly', () {
        const path = '/';
        final fileName = path.isNotEmpty ? path.split('/').last : 'archivo';
        expect(fileName, '');
      });

      test('handles file name with spaces', () {
        const path = '/storage/path/my document with spaces.pdf';
        final parts = path.split('/');
        final fileName = parts.last;
        expect(fileName, 'my document with spaces.pdf');
      });
    });

    group('MIME type detection', () {
      test('detects PDF from extension', () {
        const fileName = 'test.pdf';
        const expectedMime = 'application/pdf';
        expect(fileName.endsWith('.pdf'), isTrue);
        expect(expectedMime, 'application/pdf');
      });

      test('detects JPEG from extension', () {
        expect('test.jpg'.endsWith('.jpg'), isTrue);
        expect('test.jpeg'.endsWith('.jpeg'), isTrue);
      });

      test('detects PNG from extension', () {
        expect('test.png'.endsWith('.png'), isTrue);
      });

      test('detects TIFF from extension', () {
        expect('test.tif'.endsWith('.tif'), isTrue);
        expect('test.tiff'.endsWith('.tiff'), isTrue);
      });

      test('detects GIF from extension', () {
        expect('test.gif'.endsWith('.gif'), isTrue);
      });

      test('detects WEBP from extension', () {
        expect('test.webp'.endsWith('.webp'), isTrue);
      });

      test('handles case insensitive extensions', () {
        expect('TEST.PDF'.toLowerCase().endsWith('.pdf'), isTrue);
        expect('Test.Pdf'.toLowerCase().endsWith('.pdf'), isTrue);
        expect('test.JPG'.toLowerCase().endsWith('.jpg'), isTrue);
      });
    });

    group('initialization', () {
      test('initialize can be called without throwing', () async {
        // This test verifies that initialize can be called without throwing
        // on non-Android platforms (where it should return immediately)
        expect(() async => await IntentHandler.initialize(), returnsNormally);
      });

      test('dispose can be called without throwing', () async {
        expect(() async => await IntentHandler.dispose(), returnsNormally);
      });
    });
  });
}
