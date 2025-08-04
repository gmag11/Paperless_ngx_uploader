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
- Connection test uses the selected method.
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
