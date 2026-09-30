import 'package:flutter_test/flutter_test.dart';
import 'package:paperlessngx_uploader/services/intent_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntentHandler share payload', () {
    test('emits the batch with the names of the files that could not be read',
        () async {
      final received = <ShareReceivedBatchEvent>[];
      final sub = IntentHandler.batchEventStream.listen(received.add);

      await IntentHandler.handleSharePayload(
        SharePayload(files: ['/tmp/cache/photo.png'], errors: ['broken.pdf']),
      );
      await Future.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.hasErrors, isTrue);
      expect(received.first.errors, ['broken.pdf']);
      // The readable file is still delivered for upload.
      expect(received.first.files.map((f) => f.fileName), ['photo.png']);

      await sub.cancel();
    });

    test('a batch delivered to an attached listener is not kept as pending',
        () async {
      final received = <ShareReceivedBatchEvent>[];
      final sub = IntentHandler.batchEventStream.listen(received.add);

      await IntentHandler.handleSharePayload(
        SharePayload(files: ['/tmp/cache/photo.png'], errors: ['broken.pdf']),
      );
      await Future.delayed(Duration.zero);

      expect(received, hasLength(1));

      // If the batch stayed pending, a recreated screen would process it again.
      final pending = IntentHandler.consumePendingBatch();
      expect(pending.files, isEmpty);
      expect(pending.errors, isEmpty);

      await sub.cancel();
    });

    test('a batch with only unreadable files still reports them', () async {
      final received = <ShareReceivedBatchEvent>[];
      final sub = IntentHandler.batchEventStream.listen(received.add);

      await IntentHandler.handleSharePayload(
        SharePayload(files: const <String>[], errors: ['broken.pdf']),
      );
      await Future.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.files, isEmpty);
      expect(received.first.errors, ['broken.pdf']);

      await sub.cancel();
    });

    test('a fully readable batch produces no notice', () async {
      final received = <ShareReceivedBatchEvent>[];
      final sub = IntentHandler.batchEventStream.listen(received.add);

      await IntentHandler.handleSharePayload(
        SharePayload(files: ['/tmp/cache/document.pdf']),
      );
      await Future.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.hasErrors, isFalse);
      expect(received.first.errors, isEmpty);

      await sub.cancel();
    });

    test('parseSharePayload accepts the map payload and the legacy list', () {
      final payload = IntentHandler.parseSharePayload({
        'files': ['/tmp/cache/document.pdf'],
        'errors': ['broken.pdf'],
      });
      expect(payload.files, ['/tmp/cache/document.pdf']);
      expect(payload.errors, ['broken.pdf']);

      final legacy = IntentHandler.parseSharePayload(['/tmp/cache/document.pdf']);
      expect(legacy.files, ['/tmp/cache/document.pdf']);
      expect(legacy.errors, isEmpty);

      expect(IntentHandler.parseSharePayload(null).isEmpty, isTrue);
    });

    test('consumePendingBatch returns the pending files and errors', () async {
      await IntentHandler.handleSharePayload(
        SharePayload(files: ['/tmp/cache/document.pdf'], errors: ['broken.pdf']),
      );

      final batch = IntentHandler.consumePendingBatch();
      expect(batch.files.map((f) => f.fileName), ['document.pdf']);
      expect(batch.errors, ['broken.pdf']);

      // Consuming clears the pending batch.
      final empty = IntentHandler.consumePendingBatch();
      expect(empty.files, isEmpty);
      expect(empty.errors, isEmpty);
    });
  });
}
