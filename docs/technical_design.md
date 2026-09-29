# Technical Design: Phase 1 Reliability Improvements

## 0. Authentication Options and Flow Impact

### Supported Authentication Methods

- Username/Password (basic auth to obtain a session or use HTTP Basic where applicable)
- API Token (static token created in Paperless‑NGX user profile)

Both methods are mutually exclusive at runtime; the user selects one in the Configuration Dialog.

### Configuration Dialog Changes

- Auth Method selector: Username/Password | API Token
- Inputs:
  - For Username/Password: Server URL, Username, Password
  - For API Token: Server URL, API Token
- **Allow self-signed certificates**: Checkbox option in the Configuration Dialog. When enabled, the app will accept self-signed or otherwise invalid SSL/TLS certificates for the configured server URL.
  - **UI Location:** This option appears below the Server URL input in the Configuration Dialog.
  - **Security Implications:** Enabling this option reduces connection security by allowing potentially untrusted servers. It should only be used for trusted, private servers or testing environments. When disabled (recommended), only valid, CA-signed certificates are accepted.
- Connection test uses the selected method and certificate validation setting.
- UI must persist the selected method and only enable the relevant input fields.

### Credential Storage and Propagation

- Storage:
  - Server URL and auth method are stored in app preferences.
  - Secrets (Password or API Token) are stored using secure storage.
- Propagation:
  - On app start, configuration is loaded; the active credentials are injected into:
    - Connection checks
    - Tag fetching
    - Upload requests
- Redaction/Logging:
  - Never log secrets. Mask values in diagnostics.

### HTTP Request Authentication

- Username/Password:
  - Prefer Basic Auth header on requests needing authentication:
    - Authorization: Basic base64(username:password)
- API Token:
  - Use Token header scheme supported by Paperless‑NGX:
    - Authorization: Token {api_token}
- Header selection is conditional based on the active method. Only one Authorization header is set at a time.

### Flow Impacts

- Connection Check:
  - Uses the chosen credentials. Failure messaging distinguishes:
    - Invalid credentials (401/403)
    - Unreachable host/network (timeout/DNS)
- Tag Fetch:
  - Same Authorization strategy as above.
- Upload:
  - Apply the same Authorization strategy to the multipart upload request stream.
- Migration/Compatibility:
  - If an existing install only has Username/Password, default to that method until user switches to API Token.

## 1. Intent Handler Enhancements

### MIME Type Validation

```dart
class FileValidationResult {
  final bool isValid;
  final String? error;
  final String? mimeType;
  final int? size;
}

// Add to IntentHandler
static final Map<String, List<String>> _supportedTypes = {
  'application/pdf': ['.pdf'],
  'image/jpeg': ['.jpg', '.jpeg'],
  'image/png': ['.png'],
  'image/tiff': ['.tif', '.tiff'],
  'image/gif': ['.gif'],
  'image/webp': ['.webp']
};

static Future<FileValidationResult> validateFile(String path) async {
  // Implement MIME detection and validation
  // Check both MIME type and file extension
}
```

### File Size Handling

```dart
static const int MAX_FILE_SIZE = 200 * 1024 * 1024; // 200MB default
static const int COMPRESSION_THRESHOLD = 50 * 1024 * 1024; // 50MB for images

static Future<FileValidationResult> validateFileSize(String path) async {
  final file = File(path);
  final size = await file.length();
  
  if (size > MAX_FILE_SIZE) {
    return FileValidationResult(
      isValid: false,
      error: 'File too large (max ${MAX_FILE_SIZE ~/ (1024*1024)}MB)',
      size: size
    );
  }
  
  return FileValidationResult(isValid: true, size: size);
}
```

## 2. Upload Process Improvements

### Streamed Upload Implementation

```dart
class UploadProgress {
  final int bytesUploaded;
  final int totalBytes;
  final double progress;
  final String status;
  final bool needsCompression;
}

Future<Stream<UploadProgress>> uploadDocumentStreamed({
  required String filePath,
  required String fileName,
  String? title,
  List<int> tagIds = const [],
}) async {
  // Implementation using http.MultipartRequest with streaming
}
```

### Compression Strategy

```dart
enum CompressionStrategy {
  none,      // Never compress
  auto,      // Compress images > threshold
  always     // Always try to compress images
}

class CompressionResult {
  final String path;    // Path to compressed file (temp)
  final int originalSize;
  final int compressedSize;
  final bool wasCompressed;
}

Future<CompressionResult> prepareFileForUpload(
  String filePath,
  String mimeType,
  CompressionStrategy strategy
) async {
  if (!mimeType.startsWith('image/') || strategy == CompressionStrategy.none) {
    return CompressionResult(
      path: filePath,
      originalSize: File(filePath).lengthSync(),
      compressedSize: File(filePath).lengthSync(),
      wasCompressed: false
    );
  }
  
  // Implement image compression logic
  // Return original file if compression fails or doesn't reduce size
}
```

## 3. Retry Mechanism

### Idempotency Implementation

```dart
class UploadRequest {
  final String idempotencyKey;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String filePath;
  final String mimeType;
  final int fileSize;
}

class RetryManager {
  Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    bool Function(Exception)? shouldRetry,
  }) async {
    // Implement exponential backoff retry
  }
}
```

### Error Types

```dart
sealed class UploadError {
  final String message;
  final String? code;
  
  static NetworkError network(String msg) => NetworkError(msg);
  static ServerError server(int status, String msg) => ServerError(status, msg);
  static ValidationError validation(String msg) => ValidationError(msg);
  static FileError fileError(String msg) => FileError(msg);
}

// Specific error types
class FileError extends UploadError {
  final String path;
  final String? mimeType;
  final int? size;
}

class ValidationError extends UploadError {
  final Map<String, String>? fieldErrors;
}
```

## 4. Intent Intake (Share and "Open with")

### Registered intent filters

`android/app/src/main/AndroidManifest.xml` declares on `MainActivity`:

- `ACTION_MAIN` + `CATEGORY_LAUNCHER` (normal launch).
- `ACTION_SEND` and `ACTION_SEND_MULTIPLE` with `CATEGORY_DEFAULT` and `*/*` (the Share menu), plus a dedicated `text/plain` filter for URLs shared from a browser.
- `ACTION_VIEW` with `CATEGORY_DEFAULT`, the `content` and `file` schemes, and one `<data android:mimeType>` per supported type (PDF, JPEG, PNG, TIFF, GIF, WebP). This is what makes the app appear in the "Open with" chooser. `http(s)` is deliberately not registered here: URL sharing keeps using the `SEND` filter above.

`ACTION_VIEW` delivers a single file in `intent.data`.

### Native resolution

`ShareIntentResolver` (`android/app/src/main/kotlin/net/gmartin/paperlessngx_uploader/ShareIntentResolver.kt`) turns an incoming `Intent` into a `ShareResolution(files, errors)`:

- `ACTION_VIEW` reads `intent.data` and accepts only `content://` and `file://`.
- `ACTION_SEND` keeps the text-URL behavior and `EXTRA_STREAM`; `ACTION_SEND_MULTIPLE` iterates `EXTRA_STREAM`.
- `copyUriToCache` copies a readable `content://` URI into `cacheDir/shared_files` using its display name, and keeps the original path for a readable `file://`.
- A file that cannot be read produces no path and is added to `errors` with its display name; no exception escapes the resolver.

`MainActivity` is a thin wrapper around it: it resolves the intent, sends the payload to Dart, and replaces the intent with `ACTION_MAIN` so that an activity recreation does not re-deliver the same file (exactly-once delivery).

### Payload to Dart and the unreadable-file notice

Both `getInitialSharedFiles` and the EventChannel deliver `{files, errors}`. `IntentHandler.parseSharePayload` accepts that map (and the legacy plain list of paths), `ShareReceivedBatchEvent` carries `errors` (`hasErrors`), and `consumePendingBatch()` returns the pending batch captured before the UI attaches its listeners.

`home_screen` shows one notice per batch with `UIHelper.showMessage(context, l10n.snackbar_unreadable_files(names), success: false)` — the red toast/snackbar — naming the affected files, and counts them as an error so `finishAndRemoveTask()` is not called and the activity stays open for the user to read it. The string is `snackbar_unreadable_files` in `lib/l10n/app_en.arb` and `lib/l10n/app_es.arb`.

### Running the test suites

Dart:

```bash
flutter test
```

Android JVM (Robolectric) tests live in `android/app/src/test/kotlin/net/gmartin/paperlessngx_uploader/` and run with:

```bash
cd android && ./gradlew :app:testDebugUnitTest
```

They need the Android SDK (`android/local.properties` with `sdk.dir`, or `ANDROID_HOME`) and network access the first time to download the `android-all` jars. Robolectric 4.14.1 supports API 21–35 while the app targets SDK 36, so the tests pin `@Config(sdk = 35)`.

Coverage: the manifest intent filters (`ManifestIntentFilterTest`) and the resolver behavior (`ShareIntentResolverTest`). The lifecycle cases (cold start, warm start, activity recreation) and the notice shown on a real device are verified manually.

## Implementation Notes

1. File Handling

- Use content resolver for robust URI handling
- Stream files directly without full memory loading
- Implement proper permission checks and handling
- Add MIME type detection using both file magic numbers and extensions
- Compress images that exceed threshold size

1. Upload Process

- Use chunked transfer encoding
- Monitor and report upload progress
- Handle connection changes during upload
- Support cancellation of in-progress uploads

1. Error Recovery

- Persist upload state for recovery
- Implement proper cleanup on failures
- Add detailed logging for debugging
- Keep track of failed uploads for retry

1. Testing Strategy

- Unit tests for retry logic and MIME validation
- Integration tests for file handling
- Performance tests with various file sizes
- Test compression with different image types

## Migration Plan

1. Support both auth methods with a non-destructive migration:
   - If only Username/Password are present, select that method by default.
   - If API Token is saved, select API Token by default.
2. Add feature flags for gradual rollout if needed.
3. Monitor error rates during transition.
4. Implement rollback capability (user can switch auth method any time).

## Supported File Types

- PDF Documents (application/pdf)
- PNG Images (image/png)
- JPEG Images (image/jpeg)
- TIFF Images (image/tiff)
- GIF Images (image/gif)
- WebP Images (image/webp)

Each file type will be validated for:

1. Correct MIME type and extension matching
2. File size limits
3. File integrity (basic header check)
4. Compression eligibility (images only)
