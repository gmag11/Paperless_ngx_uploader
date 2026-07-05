## 1. Model: Add custom headers to ServerConfig

- [ ] 1.1 Add `customHeaders` field (`Map<String, String>?`) to `ServerConfig` model in `lib/models/server_config.dart`
- [ ] 1.2 Update `ServerConfig.copyWith()` to include `customHeaders` parameter
- [ ] 1.3 Update `ServerConfig.toJson()` to serialize `customHeaders` (null-safe)
- [ ] 1.4 Update `ServerConfig.fromJson()` to deserialize `customHeaders` with null fallback

## 2. Service: Inject custom headers into HTTP requests

- [ ] 2.1 Add `customHeaders` parameter to `PaperlessService` constructor in `lib/services/paperless_service.dart`
- [ ] 2.2 Update `_defaultHeaders()` static method to accept and merge custom headers into the returned map (custom headers added after auth header, never overwriting Authorization)
- [ ] 2.3 Modify `PaperlessService` constructor to merge `customHeaders` into `_dio` `BaseOptions.headers` via `_defaultHeaders()` — this ensures all requests inherit them automatically
- [ ] 2.4 Verify the Dio request interceptor does NOT log custom header *values* in debug mode; header *names* (keys) are safe to log for troubleshooting

## 3. Factory: Wire custom headers from config to service

- [ ] 3.1 Update `_createServiceForServer()` in `lib/services/paperless_service_factory.dart` to pass `server.customHeaders` to `PaperlessService` constructor
- [ ] 3.2 Update `createServiceWithCredentials()` to pass `server.customHeaders`
- [ ] 3.3 Update `createServiceForServerWithCredentials()` to pass `server.customHeaders`

## 4. UI: Custom headers section in server config dialog

- [ ] 4.1 Add a "Custom Headers" expandable section in the server configuration form in `lib/widgets/config_dialog.dart`
- [ ] 4.2 Implement add/remove header row UI with key and value `TextEditingController` pairs managed in a list
- [ ] 4.3 Add validation: at least one header row must have a non-empty key if any header has a non-empty value; empty-key rows with empty values are silently skipped on save
- [ ] 4.4 Wire the custom headers list into the `ServerConfig` creation/update logic in `_saveAndTestServer()`

## 5. Localization: New UI strings

- [ ] 5.1 Add English strings for the custom headers section (section title, add button label, key/placeholder hints, empty-key validation error) to the ARB files in `lib/l10n/`
- [ ] 5.2 Run `flutter gen-l10n` to regenerate localization code

## 6. Testing

- [ ] 6.1 Verify custom headers are included in test connection requests
- [ ] 6.2 Verify custom headers are included in tag fetch requests
- [ ] 6.3 Verify custom headers are included in document upload requests
- [ ] 6.4 Verify custom headers are NOT logged in debug output
- [ ] 6.5 Verify custom headers survive app restart (persistence)
- [ ] 6.6 Verify empty/null customHeaders does not add extra headers

## Review Workload Forecast

- **Estimated changed lines:** ~150-200
- **Chained PRs recommended:** No — single coherent change
- **400-line budget risk:** Low
- **Decision needed before apply:** No
