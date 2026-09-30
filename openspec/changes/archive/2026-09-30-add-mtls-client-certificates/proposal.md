# Proposal

## Why

Paperless-NGX is frequently published through a reverse proxy (nginx, Traefik,
mTLS-enabled ingress) that performs **mutual TLS**: it rejects any client that
does not present a valid client certificate. The app has no way to load one, so
these users cannot connect to their own server at all (GitHub issue #19). Dart's
`dart:io` already supports presenting client certificates, and the centralized
transport introduced by `centralize-http-client` provides exactly one place to
configure it, so the feature can be added safely now.

## What Changes

- Add **per-server client certificate configuration**: an enable switch, a
  certificate file, and an optional password. Disabled by default.
- Support **PKCS#12** (`.p12`/`.pfx`, certificate + private key + chain, with
  password) as the cross-platform format, and **PEM** (certificate chain plus a
  separate private key file) on platforms where `dart:io` supports it. iOS only
  supports PKCS#12, which is surfaced in the UI.
- **Store certificate material and its password in secure storage**, never in
  logs and never in the non-secret server configuration blob. On a backend that
  cannot hold the payload, fall back to an app-private file owned by the app.
- **Present the client certificate on every TLS connection to that server**, on
  every call path (connection test, protocol auto-detection, tag fetch, tag
  dialog, document upload), by wiring it into the shared transport.
- Add a **"Client certificate (mTLS)" section** to the server configuration form:
  choose file(s), enter the password, and remove/replace the certificate.
- Add an optional **custom CA certificate** for server trust, so a server signed
  by a private CA can be verified properly instead of blind-accepting any
  certificate with the existing self-signed switch.
- Report **certificate-specific errors** (rejected, expired, wrong password,
  server requires a certificate but none is configured) distinctly from generic
  SSL/network errors, with actionable messages.
- Add a **new dependency** for choosing files (the official `file_selector`
  plugin), gated to the native platforms this project builds.
- Add automated tests, including an end-to-end mTLS test that runs a local TLS
  server in Dart requiring a client certificate.
- iOS note: on the iOS scaffold only PKCS#12 is offered; PEM is hidden there.
- **BREAKING**: none — the feature is opt-in and no stored data changes format.

## Capabilities

### New Capabilities
- `client-certificates-mtls`: lets a user configure a per-server client
  certificate (and optional custom CA), stores it securely, presents it on every
  connection to that server, and reports certificate problems clearly.

### Modified Capabilities
<!-- The transport guarantees live in the new capability; paperless-http-client
     (introduced by centralize-http-client) is relied upon but its requirements
     do not change. -->

## Impact

- `lib/models/server_config.dart`: per-server mTLS metadata (enabled, format,
  custom-CA flag); secret material kept out of the JSON blob.
- `lib/services/secure_storage_service.dart`: per-server keys for certificate
  material and certificate password, and their removal.
- `lib/services/paperless_service.dart` / the centralized transport: build a
  `SecurityContext` and present the client certificate (and custom CA) on the
  `HttpClient`.
- `lib/services/paperless_service_factory.dart`: map the new per-server settings
  into the transport.
- `lib/widgets/config_dialog.dart`: new client-certificate section and validation.
- `lib/models/connection_status.dart` / `lib/services/paperless_service.dart`:
  certificate-specific connection outcomes and messages.
- `lib/l10n/app_en.arb` / `app_es.arb`: new strings.
- `pubspec.yaml`: new `file_selector` dependency.
- `test/`: storage round-trip, validation, and an end-to-end mTLS test.
- Depends on `centralize-http-client`; implement that first.

## Non-goals

- Web support (the project targets Android; `dart:io` is already used
  unconditionally and web is not a build target).
- Hardware-backed key storage, Android Keystore / iOS Secure Enclave integration,
  or PKCS#11 / smartcard readers.
- Certificate generation, renewal or ACME automation: the user provides the
  certificate.
- Sending the client certificate to arbitrary shared-link downloads (that
  traffic stays isolated, per `paperless-http-client`).
- Changing the existing self-signed-certificate switch beyond combining it with
  and validating the new certificate options.
