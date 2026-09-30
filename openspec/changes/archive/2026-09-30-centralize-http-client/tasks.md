# Tasks

## 1. Transport model

- [x] 1.1 Introduce `ServerTransportConfig` (base URL, auth material, custom
  headers, TLS trust policy) and make `PaperlessService` accept it; verify the
  app still builds with `flutter analyze`.
- [x] 1.2 Allow an optional `Dio` to be injected into `PaperlessService` for
  tests; verify with a unit test that injects an `http_mock_adapter` and reads
  back the request.

## 2. Factory as the single construction point

- [x] 2.1 Add `PaperlessServiceFactory.createServiceForConfig(ServerConfig config,
  {String? password, String? apiToken})`; verify it returns a service whose
  transport matches the given config.
- [x] 2.2 Make the factory map `ServerConfig` → `ServerTransportConfig` and resolve
  credentials in one place; verify the existing `createService*` methods still
  return a working service.

## 3. Migrate call sites

- [x] 3.1 Replace the direct `PaperlessService(...)` builds in
  `lib/screens/home_screen.dart` (tag dialog and `_getTagsForCurrentServer`) with
  factory calls; verify a manual tag-dialog open against a configured server
  works and sends custom headers.
- [x] 3.2 Replace the direct builds in `lib/widgets/config_dialog.dart`
  (`_saveAndTestServer`) with the draft-config factory call; verify "Save and
  test" still connects and persists.
- [x] 3.3 Replace both direct builds in `_determineProtocol` with draft-config
  factory calls, preserving the HTTPS-then-HTTP order; verify a server address
  entered without a protocol resolves correctly.
- [x] 3.4 Add a comment in `lib/providers/upload_provider.dart` documenting that
  the arbitrary-URL download client is intentionally isolated; verify no behavior
  change in the shared-link upload path.

## 4. Tests and regression guard

- [x] 4.1 Add a test asserting custom headers are present on tag fetch,
  connection test and protocol detection; verify it fails before 3.1–3.3 and
  passes after.
- [x] 4.2 Add a test asserting the TLS trust policy (self-signed on/off) applies
  to those same paths; verify both directions.
- [x] 4.3 Add the repository guard test that scans `lib/**/*.dart` for Paperless
  client constructions outside the factory; verify it passes and that
  reintroducing a direct construction makes it fail.
- [x] 4.4 Run `flutter test` and `flutter analyze` clean.

## 5. Per-server TLS policy in the config form

- [x] 5.1 Make the self-signed switch form-local state seeded from the server
  being edited (and `false` for a new server); verify `flutter analyze` is clean.
- [x] 5.2 Use the form value for the connection test, protocol detection and the
  saved configuration, with no write-through to the selected server; verify by
  inspection that the dialog no longer calls
  `AppConfigProvider.setAllowSelfSignedCertificates`.
- [x] 5.3 Verify that editing a non-selected server shows and saves that server's
  value and leaves the selected server unchanged (requires a multi-server device
  check, recorded as the manual verification for this change).
