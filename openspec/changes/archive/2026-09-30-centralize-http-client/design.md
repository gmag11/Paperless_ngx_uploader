# Design

## Context

See `proposal.md` for motivation. Current state relevant to the approach:

- `PaperlessService` (`lib/services/paperless_service.dart`) owns a `Dio` client
  and the per-server transport settings it is given: `baseUrl`, auth
  (`useApiToken`/`apiToken`/username+password), `allowSelfSignedCertificates`
  and `customHeaders`.
- `PaperlessServiceFactory` (`lib/services/paperless_service_factory.dart`) can
  already resolve the selected/known server and its credentials from storage, but
  only `AppConfigProvider.getPaperlessService()` uses it.
- Five call sites construct `PaperlessService` directly and pass their own subset
  of settings: `home_screen.dart` (tag dialog, `_getTagsForCurrentServer`) and
  `config_dialog.dart` (`_saveAndTestServer`, `_determineProtocol` twice). Those
  sites omit `customHeaders`.
- `upload_provider.dart` builds a bare `Dio()` to download an arbitrary shared
  URL; that request is not a Paperless-NGX request.

## Goals / Non-Goals

**Goals:**
- One construction point for Paperless-NGX clients, usable both for saved
  servers and for draft (unsaved) configurations.
- Transport settings expressed as a single value passed to the client, so future
  settings (client certificates) plug in once.
- Behavior parity and a regression guard that prevents new ad-hoc construction.

**Non-Goals:**
- Any change to request semantics, endpoints, retries or timeouts.
- Refactoring the upload flow or the tag dialog behavior.
- Merging the arbitrary-URL download client with the Paperless client.

## Decisions

1. **Extend `PaperlessServiceFactory` rather than add a new builder class.**
   The factory already owns server + credential resolution, so it is the natural
   single point. Add `createServiceForConfig(ServerConfig config, {String? password,
   String? apiToken})` for draft configurations coming from the server form, and
   keep the existing `createService*` methods.
   - *Why*: minimal new surface, keeps dependency-injection style, and no call
     site needs to reimplement credential lookup.
   - *Discarded alternative*: a separate `PaperlessClientBuilder`. It would
     duplicate server/credential resolution or force a second wiring path,
     defeating the goal.

2. **Introduce a transport value object (`ServerTransportConfig`) that bundles
   base URL, auth material, custom headers and TLS trust policy; `PaperlessService`
   takes it (plus credentials).** The factory is the only place that maps a
   `ServerConfig` to this object.
   - *Why*: today the constructor parameter list is growing and each call site
     picks a subset — exactly the failure mode being fixed. A bundle makes the
     mapping explicit and testable, and lets the mTLS change add one field in one
     place.
   - *Discarded alternative*: keep adding named parameters and rely on discipline.
     That is what produced the current drift.

3. **Draft configurations pass credentials explicitly.** `config_dialog` reads the
   typed username/password/token from its controllers and calls
   `createServiceForConfig(...)`; saved servers resolve credentials from secure
   storage as today.
   - *Why*: the connection test and protocol detection run before persistence.

4. **Protocol auto-detection keeps its HTTPS-then-HTTP order**, but both attempts
   are built through the factory for the same draft config, so headers and trust
   policy are identical on both.

5. **The arbitrary-URL download client stays separate and is documented as such.**
   - *Why*: it downloads a link from another app and must not leak Paperless
     credentials or client certificates to an unknown host.
   - *Discarded alternative*: reuse the Paperless client for the download. It
     would send `Authorization`, custom headers and (after the mTLS change) the
     client certificate to an arbitrary URL — a security regression.

6. **Regression guard as an automated test.** A `flutter test` walks `lib/**/*.dart`
   and fails if a Paperless-NGX client construction appears outside the factory
   file, listing the offending paths.
   - *Why*: it converts "centralized" from a convention into an enforced
     invariant, cheaply.
   - *Discarded alternative*: an analyzer rule or CI grep. A test lives with the
     rest of the suite and needs no extra configuration.

7. **Optional `Dio` injection into `PaperlessService` for tests**, so header
   propagation can be asserted with the existing `http_mock_adapter` dev
   dependency.
   - *Why*: lets the suite prove headers/auth actually reach the wire on every
     path, not just that the field is set.

8. **The self-signed switch is form-local state of the configuration dialog, not
   provider-backed.** The dialog seeds it from the server being edited (or the
   default `false` for a new server) and commits it into the saved configuration.
   - *Why*: `AppConfigProvider.allowSelfSignedCertificates` resolves the
     *selected* server, so when the user edited a non-selected server (or added
     one while another was selected) the test and the saved configuration used
     the wrong server's policy. Toggling also wrote through to the selected
     server instead of the draft, mutating a different server.
   - *Discarded alternative*: keep the provider binding and pass the edited
     server's id into the provider. It would still write through on every toggle
     and would rely on the provider method that rebuilds a `ServerConfig` from
     scratch; the separate config-preservation change addresses that method.
   - Note: this removes the only call to the provider's
     `setAllowSelfSignedCertificates`; the method itself is fixed by the
     dedicated config-preservation change.

## Risks / Trade-offs

- [Enabling custom headers on paths that previously dropped them can change
  requests] → This is the intended compliance with `custom-request-headers`; the
  README/existing behavior already documents the headers. Verified by tests.
- [Refactoring `_determineProtocol` and `_saveAndTestServer` can regress the
  save flow] → Both keep their observable behavior (same order, same result
  mapping) and are covered by the draft-config test.
- [The repo guard may be brittle if the constructor is renamed] → The guard uses
  the single construction token and lives next to the factory; renaming it is a
  deliberate, visible change.
- [A transport bundle adds an indirection layer] → Small, mechanical, one file;
  it removes the growing parameter list rather than adding complexity.

## Migration Plan

Pure internal refactor shipped in a normal app update; no stored data or schema
changes. Order: introduce the transport bundle and factory entry points, migrate
call sites one by one, add the tests, then enable the repo guard last (so it
fails only after migration is complete). Reverting the commit restores the
previous construction sites.
