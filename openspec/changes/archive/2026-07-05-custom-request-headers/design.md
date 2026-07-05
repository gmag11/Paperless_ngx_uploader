## Context

Paperless-ngx Android Uploader is a Flutter app that sends documents to a Paperless-ngx server via its REST API. The app uses the `dio` HTTP client with auth configured via `BaseOptions.headers` (shared across all requests) and per-request `Options.headers` override. Currently only `Authorization` (Basic or Token) is set.

Users who place Paperless-ngx behind authenticating reverse proxies like Pangolin need to inject proxy-specific headers (`P-Access-Token-Id`, `P-Access-Token`, etc.) that the app has no mechanism to provide. This blocks use of the app in proxied setups unless the proxy's auth is bypassed — a security compromise.

## Goals / Non-Goals

**Goals:**
- Allow per-server configuration of arbitrary custom HTTP headers (key-value pairs)
- Inject custom headers into every HTTP request the app makes to that server
- Provide UI for adding/removing custom headers in the server config dialog
- Keep header values out of debug logs
- Persist headers alongside existing server configuration

**Non-Goals:**
- Per-request conditional headers (e.g., only for upload, not for tag fetch)
- Header value encryption beyond existing secure storage
- Header templating or dynamic values (e.g., timestamps, request signatures)
- Server-side validation of custom headers
- Import/export of custom header presets

## Decisions

### Decision 1: Store custom headers as `Map<String, String>` on `ServerConfig`
**Rationale:** A simple key-value map is the most natural representation. Dio's `BaseOptions.headers` already accepts `Map<String, String>`, so there is zero conversion overhead. No need for a custom class — headers are inherently flat key-value pairs.

**Alternatives considered:**
- `List<MapEntry<String, String>>`: More complex to serialize/deserialize in JSON, harder to merge with Dio's map-based API.
- `Map<String, List<String>>` (multi-value headers): Over-engineering. HTTP allows multi-value headers but practical proxy auth headers are single-value.

### Decision 2: Merge custom headers into Dio `BaseOptions.headers` at construction time
**Rationale:** Dio's `BaseOptions.headers` are automatically included in every request made through that client instance. Merging at construction time (in `PaperlessService` constructor) means no per-request code changes needed — all methods (`testConnection`, `fetchTags`, `uploadDocument`) inherit them automatically.

**Alternatives considered:**
- Per-request header injection via interceptor: Adds complexity for no benefit in this case. Dio already carries base headers on every request.
- Per-method manual merge: Error-prone; each method would need to remember to include custom headers.

### Decision 3: Custom headers in server config form as a simple add/remove row UI
**Rationale:** A list of key-value text fields is the simplest UX that covers the use case. Fancy key-value editors are overkill for the expected 1-3 header pairs.

**Alternatives considered:**
- JSON text area: Powerful but error-prone for non-technical users.
- Predefined header dropdown: Not possible — headers are proxy-specific and unknown at build time.

### Decision 4: Log custom header names but never values
**Rationale:** Custom header values often carry bearer tokens or access secrets (like Pangolin's `P-Access-Token`). Logging values would leak credentials. However, logging the header *names* (keys) is safe and useful for debugging — knowing which custom headers are being sent helps diagnose proxy auth issues. The Dio interceptor already logs request URIs but not headers; we ensure header values are never logged while keys may appear in debug output for troubleshooting.

## Risks / Trade-offs

- **[Risk] User typo in header key breaks auth silently** → Mitigation: The "Test Connection" button already exists; after adding headers, users can verify connectivity. A successful test confirms headers are valid.
- **[Risk] Custom header key conflicts with Dio's default headers** → Mitigation: Custom headers are merged AFTER auth headers, so they cannot override `Authorization`. If a user sets a conflicting key, Dio's behavior is predictable (last-write-wins for that key in the same map, but since custom headers are separate from auth, there's no conflict).
- **[Trade-off] Flat key-value lacks header ordering guarantee** → Acceptable: HTTP headers are order-independent per spec. No known reverse proxy requires ordered headers.
- **[Trade-off] Headers are global per server, not per-endpoint** → Acceptable for the Pangolin use case. Can be extended later if needed without breaking existing configs.
