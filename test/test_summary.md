# Test Suite Summary

This document summarizes the existing tests in the `test/` directory. It describes each test at a high level, outlines covered scenarios, expected results, and groups them by functionality with rationale.  
**Note:** The suite now includes comprehensive coverage for SSL certificate validation and the "allow self-signed certificates" option, ensuring correct persistence, propagation, and runtime behavior.

## Test Tables by File

### [`test/app_config_provider_test.dart`](test/app_config_provider_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| Saves and loads Username/Password via SecureStorageService | Validate persistence and recovery of Username/Password configuration through provider and secure storage | Save configuration with server URL, username, password; then load configuration | Provider fields reflect saved values; `isConfigured = true`; `apiToken = null`; method set to Username/Password |
| Saves and loads API Token via SecureStorageService | Validate persistence and recovery of API Token configuration | Save configuration with server URL and token (empty username triggers token mode); then load configuration | Provider reflects token mode; `apiToken` set; `username/password` cleared to `''`; `isConfigured = true` |
| getPaperlessService reflects username/password and baseUrl | Ensure provider constructs `PaperlessService` with correct basic-auth credentials and normalized base URL | Save Username/Password configuration and get service | Service not null; `baseUrl` normalized; `username/password` present; `useApiToken = false` |
| getPaperlessService reflects API token method and value | Ensure provider constructs `PaperlessService` with token auth and trims trailing slash on base URL | Save Token configuration with trailing slash base URL; get service | Service not null; `baseUrl` trimmed; `useApiToken = true`; `apiToken` set; `username/password` empty |
| Cache invalidates when credentials or method change | Verify service instance cache invalidation on configuration mutations | Save config; get service; change password; get service; switch to token; get service | Service instances differ after each change; last service uses token mode |
| Switch Username/Password -> API Token updates state correctly | Validate state transitions when switching auth method to token | Start with user/pass; switch to token | Provider switches to token; clears user/pass to `''`; `isConfigured = true`; service uses token |
| Switch API Token -> Username/Password updates state correctly | Validate state transitions when switching back to user/pass | Start with token; switch to user/pass | Provider switches to user/pass; `apiToken = null`; `isConfigured = true`; service uses basic auth |
| testConnection updates connectionStatus from PaperlessService | Verify provider's connection status transitions and final mapping (without network) | Configure token; call `testConnection()`; assert final state is within allowed enum outcomes | `connectionStatus` transitions to `connecting` then to one of: connected/invalidCredentials/serverUnreachable/invalidServerUrl/sslError/unknownError |
| Manual store with SecureStorageService then loadConfiguration | Ensure provider loads pre-existing stored Username/Password credentials | Persist via `SecureStorageService`; call `provider.loadConfiguration()` | Provider mirrors stored values; `PaperlessService` created with basic auth |
| Manual store for token then loadConfiguration maps correctly | Ensure provider loads pre-existing stored token credentials | Persist token via `SecureStorageService`; call `provider.loadConfiguration()` | Provider in token mode with `apiToken` set; `username/password` cleared; service uses token |
| Loads default false value when no SSL setting stored | Ensure SSL flag defaults to false if not present in storage | Load configuration with no SSL flag present | `allowSelfSignedCertificates` is `false` |
| Loads stored SSL setting from secure storage | Ensure SSL flag is loaded as true from storage | Store SSL flag as true; load configuration | `allowSelfSignedCertificates` is `true` |
| Loads false SSL setting from secure storage | Ensure SSL flag is loaded as false from storage | Store SSL flag as false; load configuration | `allowSelfSignedCertificates` is `false` |
| Persists SSL setting via setAllowSelfSignedCertificates | Ensure SSL flag is persisted to storage | Set SSL flag to true; check storage | Storage reflects `true`; provider reflects `true` |
| Persists SSL setting changes via setAllowSelfSignedCertificates | Ensure SSL flag changes are persisted | Set SSL flag to true, then false | Storage reflects changes; provider reflects changes |
| Clear configuration removes SSL setting | Ensure clearing config removes SSL flag from storage | Set SSL flag; clear config | Storage SSL flag is null; provider flag is `false` |
| PaperlessService receives allowSelfSignedCertificates=false by default | Ensure PaperlessService gets SSL validation enabled by default | Save config; get service | Service created with SSL validation enabled |
| PaperlessService receives allowSelfSignedCertificates=true when set | Ensure PaperlessService gets SSL validation disabled when flag is set | Save config; set SSL flag true; get service | Service created with SSL validation disabled |
| Cache invalidates when SSL setting changes | Ensure service cache invalidates on SSL flag change | Save config; get service; change SSL flag; get service | Service instances differ after SSL flag change |
| SSL setting included in cache invalidation check | Ensure SSL flag is part of cache key | Save config; set SSL flag; get service; change SSL flag; get service | Service instances differ after SSL flag change |
| Complete configuration round-trip with SSL setting | Ensure full persistence and restoration of SSL flag with config | Save config; set SSL flag; reload config | All fields and SSL flag restored |
| SSL setting survives configuration changes | Ensure SSL flag persists across config changes | Set SSL flag; change config | SSL flag remains set in provider and storage |

### [`test/secure_storage_service_test.dart`](test/secure_storage_service_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| Username/Password: saving and retrieving | Validate storage and retrieval of user/pass credentials | Save user/pass; get credentials; check presence | Stored values match; `hasCredentials() = true` |
| API Token: saving and retrieving | Validate storage and retrieval of token credentials | Save token; get credentials; check presence | Stored values match token mode; `hasCredentials() = true` |
| Switch from Username/Password to API Token clears old creds | Ensure switching method removes stale user/pass keys | Save user/pass; save token on same server | Stored mode is token; user/pass keys are absent; `hasCredentials() = true` |
| Switch from API Token to Username/Password clears token | Ensure switching back removes stale token | Save token; save user/pass | Stored mode is user/pass; token key is absent; `hasCredentials() = true` |
| Clear removes all keys and hasCredentials becomes false | Validate clearing all stored credentials | Save some creds; clear; read back; check presence | All keys null; `hasCredentials() = false` |
| Username/Password: missing username fails hasCredentials | Validate presence logic for missing username | Save with missing username | `hasCredentials() = false` |
| Username/Password: missing password fails hasCredentials | Validate presence logic for missing password | Save with missing password | `hasCredentials() = false` |
| API Token: missing token fails hasCredentials | Validate presence logic for missing token | Save with missing `apiToken` | `hasCredentials() = false` |
| Server URL missing fails hasCredentials | Ensure missing server URL results in false presence | Manipulate store to end with missing server URL | `hasCredentials() = false` |

### [`test/paperless_service_test.dart`](test/paperless_service_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| Generates Basic auth header for username/password | Ensure Basic Authorization header formatting | Compute expected Basic header; stub GET requiring header; request with header | 200 OK received; header matches expected format |
| Generates Token auth header for API token | Ensure Token Authorization header formatting and trimming | Compute expected Token header with trimmed token; stub GET requiring header; request with header | 200 OK received; header matches expected format |
| Malformed/empty token still sends "Authorization: Token " | Confirm behavior for empty/whitespace token | Expect `"Token "` header; stub GET; request with header | 401 Unauthorized received; mapping symbol assertion holds |
| Creates Dio instance with SSL validation enabled by default | Ensure SSL validation is enabled by default | Create service with no SSL flag | Service created with SSL validation enabled |
| Creates Dio instance with SSL validation disabled when allowSelfSignedCertificates=true | Ensure SSL validation is disabled when flag is set | Create service with SSL flag true | Service created with SSL validation disabled |
| Creates Dio instance with SSL validation enabled when allowSelfSignedCertificates=false | Ensure SSL validation is enabled when flag is false | Create service with SSL flag false | Service created with SSL validation enabled |
| SSL setting applies to API token authentication as well | Ensure SSL flag is respected for API token auth | Create service with API token and SSL flag true | Service created with SSL validation disabled |
| Maps 200 to connected | Validate mapping of 200 to connected (symbolic) | Stub GET 200 with Basic header | Assert 200; symbolic enum equality |
| Maps 401 to invalidCredentials | Validate mapping of 401 to invalid credentials (symbolic) | Stub GET 401 | Assert 401; symbolic enum equality |
| Maps 404 to invalidServerUrl | Validate mapping of 404 to invalid server URL (symbolic) | Stub GET 404 | Assert 404; symbolic enum equality |
| Maps DioException.connectionError to serverUnreachable | Symbolic expectation for connectivity errors | No network call; reference enum value | Enum value equals itself |
| Maps HandshakeException to sslError | Symbolic expectation for SSL errors | No network call; reference enum value | Enum value equals itself |

### [`test/home_screen_test.dart`](test/home_screen_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| shows warning banner when showTypeWarning is true | Ensure HomeScreen shows localized banner when MIME type warning is active | Provide stubbed providers; toggle warning true with MIME type; use real localization delegates | Localized banner text appears exactly once when enabled |
| renders progress card with percentage and bytes while uploading | Ensure upload progress UI elements show/hide correctly | Toggle progress state to uploading with bytes and percent; then finish and reset | `LinearProgressIndicator` appears during upload; percentage texts found; indicator hidden after reset |

### [`test/intent_handler_test.dart`](test/intent_handler_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| creates event with correct properties | Validate ShareReceivedEvent creation with full properties | Create ShareReceivedEvent with all properties | All properties match input values |
| creates event with minimal properties | Validate ShareReceivedEvent creation with optional properties | Create ShareReceivedEvent with minimal required properties | Optional properties are null; required properties match |
| creates batch event with correct properties | Validate ShareReceivedBatchEvent creation and file counting | Create batch event with multiple files | totalFiles and supportedFilesCount match file list |
| detects unsupported files in batch | Validate unsupported file detection in batch processing | Create batch with mixed supported/unsupported files | hasUnsupportedFiles is true; supportedFilesCount reflects only supported files |
| handles empty file list | Validate empty batch handling | Create batch event with empty file list | totalFiles and supportedFilesCount are 0; hasUnsupportedFiles is false |
| handles all unsupported files | Validate all unsupported batch handling | Create batch with only unsupported files | supportedFilesCount is 0; hasUnsupportedFiles is true |
| event streams are broadcast streams | Validate stream properties for multiple listeners | Check stream types | Both streams are broadcast streams |
| contains expected MIME type mappings | Validate supported file type mappings | Check supportedTypes map contents | Contains expected PDF and image type mappings |
| extract file name from full path | Validate file name extraction from full path | Parse "/storage/emulated/0/Downloads/test.pdf" | Returns "test.pdf" |
| handles file without extension | Validate file name extraction without extension | Parse "/storage/emulated/0/Downloads/document" | Returns "document" |
| handles empty path with default name | Validate empty path handling | Parse empty string | Returns "archivo" |
| handles root path correctly | Validate root path handling | Parse "/" | Returns empty string |
| handles file name with spaces | Validate file name with spaces | Parse "/storage/path/my document with spaces.pdf" | Returns "my document with spaces.pdf" |
| initialize can be called without throwing | Validate initialization behavior | Call IntentHandler.initialize() | Returns normally without throwing |
| dispose can be called without throwing | Validate cleanup behavior | Call IntentHandler.dispose() | Returns normally without throwing |

### [`test/permission_service_test.dart`](test/permission_service_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| has storage permission constant | Validate permission constants exist | Check Permission.storage | Permission.storage is not null |
| has photos permission constant | Validate permission constants exist | Check Permission.photos | Permission.photos is not null |
| has videos permission constant | Validate permission constants exist | Check Permission.videos | Permission.videos is not null |
| has audio permission constant | Validate permission constants exist | Check Permission.audio | Permission.audio is not null |
| has granted status | Validate permission status constants exist | Check PermissionStatus.granted | PermissionStatus.granted is not null |
| has denied status | Validate permission status constants exist | Check PermissionStatus.denied | PermissionStatus.denied is not null |
| has restricted status | Validate permission status constants exist | Check PermissionStatus.restricted | PermissionStatus.restricted is not null |
| has permanently denied status | Validate permission status constants exist | Check PermissionStatus.permanentlyDenied | PermissionStatus.permanentlyDenied is not null |
| has limited status | Validate permission status constants exist | Check PermissionStatus.limited | PermissionStatus.limited is not null |

### [`test/upload_initiation_test.dart`](test/upload_initiation_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| initiates file upload with valid file path | Validate upload initiation with valid file | Create upload with valid file path | Upload initiated successfully |
| handles empty file path gracefully | Validate upload initiation with empty path | Create upload with empty file path | Handles gracefully without crash |
| handles null file path gracefully | Validate upload initiation with null path | Create upload with null file path | Handles gracefully without crash |
| validates file path format | Validate file path validation | Test various file path formats | Validates correctly for valid/invalid paths |
| handles upload cancellation | Validate upload cancellation behavior | Start upload then cancel | Cancellation handled properly |

### [`test/widget_test.dart`](test/widget_test.dart)
| Test Name | Purpose | Scenarios Covered | Expected Result |
|---|---|---|---|
| template widget test disabled | Placeholder template test disabled for this project | Skipped unimplemented template | Test is skipped; no effect |

## Classification by Functionality

1) Configuration and State Management (AppConfigProvider)

- Files: `app_config_provider_test.dart`
- Importance: Verifies core configuration flows (auth method switching, persistence, service propagation, connection status transitions, and SSL/self-signed certificate flag). These tests ensure reliable loading/saving of credentials, correct SSL flag handling, and consistent behavior across method and SSL changes, directly affecting onboarding, connectivity, and security UX.

2) Secure Storage Layer (SecureStorageService)

- Files: `secure_storage_service_test.dart`
- Importance: Ensures secrets and non-secrets are stored and validated correctly. Critical for security, correctness of persisted state, and determining whether the app can operate without reconfiguration.

3) HTTP/Auth/SSL Integration Semantics (PaperlessService)

- Files: `paperless_service_test.dart`
- Importance: Validates correctness of Authorization headers, expected mapping of HTTP outcomes to connection statuses, and SSL certificate validation logic. Fundamental for interoperability with Paperless‑NGX, secure communications, and for clear error reporting in the UI.

4) UI Rendering and Feedback (HomeScreen)

- Files: `home_screen_test.dart`
- Importance: Confirms critical UI feedback behaviors (warnings and upload progress visibility) and integration with localization. Directly impacts user trust and usability during upload operations.

5) Intent Handling and File Processing

- Files: `intent_handler_test.dart`
- Importance: Validates Android intent handling for file sharing, supported file type detection, file name extraction from paths, and batch file processing. Critical for core app functionality when receiving files from external apps.

6) Permission Management

- Files: `permission_service_test.dart`
- Importance: Validates permission type constants and status values used for file access permissions. Essential for permission handling in the Android app.

7) Upload Initiation

- Files: `upload_initiation_test.dart`
- Importance: Validates the upload initiation process with various file path scenarios, including edge cases and cancellation handling. Ensures robust upload functionality.

8) Template/Scaffold

- Files: `widget_test.dart`
- Importance: Disabled placeholder; no functional impact, but indicates standard Flutter template scaffolding has been intentionally skipped.
