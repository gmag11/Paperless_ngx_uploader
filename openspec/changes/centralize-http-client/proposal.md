# Proposal

## Why

Every Paperless-NGX call must share the same transport configuration (base URL,
timeouts, authorization header, per-server custom headers, TLS trust policy),
but `PaperlessService` instances are built in several unrelated places and
several call paths bypass `PaperlessServiceFactory`. As a result, per-server
settings are applied inconsistently: the tag dialog and the tag-fetch helper in
`lib/screens/home_screen.dart`, and the connection test and protocol detection in
`lib/widgets/config_dialog.dart`, construct `PaperlessService` directly and drop
`customHeaders`. This violates the existing `custom-request-headers` contract and
makes any future cross-cutting transport feature (such as client certificates for
mTLS) unsafe to add, because it would have to be threaded by hand through every
ad-hoc construction site.

## What Changes

- Make a single factory the only place in `lib/` that turns a server
  configuration into a Paperless-NGX API client.
- Extend the factory with an entry point for a **draft** (not yet persisted)
  configuration, so the "Save and test" connection test and the protocol
  auto-detection keep working before a server exists.
- Route the direct constructions through the factory: `home_screen.dart` (tag
  dialog and `_getTagsForCurrentServer`) and `config_dialog.dart`
  (`_saveAndTestServer` and `_determineProtocol`).
- Guarantee that every Paperless-NGX request carries the complete per-server
  transport configuration (authorization header, custom headers, TLS trust /
  self-signed policy) on every call path.
- Keep the arbitrary-URL download in `upload_provider.dart` intentionally
  separate: it downloads a link shared from another app, never a Paperless-NGX
  endpoint, and MUST NOT carry Paperless credentials, custom headers or client
  certificates. No behavior change there.
- Add automated tests: custom headers reaching the formerly-exempt paths, and a
  repository guard that fails if a Paperless-NGX client is constructed outside
  the factory.
- No new dependencies.

## Capabilities

### New Capabilities
- `paperless-http-client`: guarantees that all Paperless-NGX API traffic is
  performed by a single, centrally-configured HTTP transport, and that per-server
  settings (authentication, custom headers, TLS trust policy) apply uniformly on
  every call path.

### Modified Capabilities
<!-- custom-request-headers already requires custom headers on "every request";
     this change makes the implementation comply with that requirement instead of
     changing it, so no delta is needed there. -->

## Impact

- `lib/services/paperless_service_factory.dart`: becomes the single construction
  point; new entry point for draft configurations.
- `lib/services/paperless_service.dart`: accepts a resolved transport
  configuration; request semantics unchanged.
- `lib/screens/home_screen.dart`: two direct `PaperlessService(...)` builds
  replaced by factory calls.
- `lib/widgets/config_dialog.dart`: three direct `PaperlessService(...)` builds
  replaced; test and protocol detection use the draft-configuration entry point.
- `lib/providers/upload_provider.dart`: the standalone download client is
  documented as intentionally isolated (no functional change).
- `test/`: new tests for transport uniformity and the repo guard.
- No changes to the Paperless-NGX REST API, to stored data, or to app
  dependencies.

## Non-goals

- Adding retries, backoff, timeouts or any new transport behavior.
- Reworking the upload flow, the tag dialog UI or the authentication scheme.
- Unifying the arbitrary-URL download client with the Paperless client (they have
  deliberately different trust and credential requirements).
- Adding client-certificate (mTLS) support; that is a separate change
  (`add-mtls-client-certificates`) that depends on this one.
