# Tasks

## 1. Transport model

- [ ] 1.1 Introduce `ServerTransportConfig` (base URL, auth material, custom
  headers, TLS trust policy) and make `PaperlessService` accept it; verify the
  app still builds with `flutter analyze`.
- [ ] 1.2 Allow an optional `Dio` to be injected into `PaperlessService` for
  tests; verify with a unit test that injects an `http_mock_adapter` and reads
  back the request.

## 2. Factory as the single construction point

- [ ] 2.1 Add `PaperlessServiceFactory.createServiceForConfig(ServerConfig config,
  {String? password, String? apiToken})`; verify it returns a service whose
  transport matches the given config.
- [ ] 2.2 Make the factory map `ServerConfig` → `ServerTransportConfig` and resolve
  credentials in one place; verify the existing `createService*` methods still
  return a working service.

## 3. Migrate call sites

- [ ] 3.1 Replace the direct `PaperlessService(...)` builds in
  `lib/screens/home_screen.dart` (tag dialog and `_getTagsForCurrentServer`) with
  factory calls; verify a manual tag-dialog open against a configured server
  works and sends custom headers.
- [ ] 3.2 Replace the direct builds in `lib/widgets/config_dialog.dart`
  (`_saveAndTestServer`) with the draft-config factory call; verify "Save and
  test" still connects and persists.
- [ ] 3.3 Replace both direct builds in `_determineProtocol` with draft-config
  factory calls, preserving the HTTPS-then-HTTP order; verify a server address
  entered without a protocol resolves correctly.
- [ ] 3.4 Add a comment in `lib/providers/upload_provider.dart` documenting that
  the arbitrary-URL download client is intentionally isolated; verify no behavior
  change in the shared-link upload path.

## 4. Tests and regression guard

- [ ] 4.1 Add a test asserting custom headers are present on tag fetch,
  connection test and protocol detection; verify it fails before 3.1–3.3 and
  passes after.
- [ ] 4.2 Add a test asserting the TLS trust policy (self-signed on/off) applies
  to those same paths; verify both directions.
- [ ] 4.3 Add the repository guard test that scans `lib/**/*.dart` for Paperless
  client constructions outside the factory; verify it passes and that
  reintroducing a direct construction makes it fail.
- [ ] 4.4 Run `flutter test` and `flutter analyze` clean.
