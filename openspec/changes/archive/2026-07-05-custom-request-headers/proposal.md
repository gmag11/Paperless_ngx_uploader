## Why

Users who place Paperless-ngx behind a reverse proxy with custom authentication (e.g., Pangolin) cannot use this app because the proxy requires extra HTTP headers (like `P-Access-Token-Id` and `P-Access-Token`) that the app has no way to send. The only workaround today is to bypass the proxy's authentication entirely — a security downgrade. This feature lets users add arbitrary custom headers per server so the app works with any authenticating reverse proxy without weakening security.

## What Changes

- Add a new `customHeaders` field (list of key-value pairs) to the `ServerConfig` model, persisted alongside existing server settings.
- Extend the server configuration UI with a section to add, edit, and remove custom header key/value pairs.
- Modify `PaperlessService` to merge custom headers into every outgoing request (auth, tag fetch, upload, etc.).
- Ensure custom headers are stored securely (not logged in plaintext) and excluded from debug output.

## Capabilities

### New Capabilities
- `custom-request-headers`: Allow users to define arbitrary HTTP headers per Paperless-ngx server configuration that are included in all API requests to that server.

### Modified Capabilities
<!-- None - no existing specs change their requirements -->

## Impact

- **Model**: `ServerConfig` — new `customHeaders` field (`Map<String, String>?`), `toJson`/`fromJson`/`copyWith` updated.
- **Service**: `PaperlessService` — constructor accepts custom headers; `_defaultHeaders()` merges them; all request methods inherit them via Dio `BaseOptions.headers`.
- **Factory**: `PaperlessServiceFactory` — passes custom headers from `ServerConfig` to `PaperlessService`.
- **UI**: `ConfigDialog` — new section in server form for managing custom headers (add/remove key-value rows).
- **Localization**: New strings needed for the custom headers UI section.
- **Storage**: `ServerManager` — existing JSON persistence covers the new field automatically; no schema migration needed for the optional nullable field.
