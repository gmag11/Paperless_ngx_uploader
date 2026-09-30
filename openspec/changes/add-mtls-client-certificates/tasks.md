# Tasks

Prerequisite: `centralize-http-client` is implemented first, so the transport
has a single construction point to extend.

## 1. Model and storage

- [ ] 1.1 Add non-secret mTLS metadata to `ServerConfig` (enabled, format, custom
  CA present) with backward-compatible `fromJson`/`toJson`; verify an existing
  stored server still loads with the option disabled.
- [ ] 1.2 Add per-server secure-storage keys and methods for the certificate,
  private key, password and CA, plus deletion; verify a save/read/delete
  round-trip test passes.
- [ ] 1.3 Implement the app-private-file fallback for material a backend cannot
  hold, and ensure certificate material never uses the plaintext preferences
  fallback; verify a test that simulates a rejecting backend.

## 2. Transport wiring

- [ ] 2.1 Build a `SecurityContext` from the stored material (PKCS#12 and PEM)
  in the centralized transport and attach it via `createHttpClient`; verify the
  in-process mTLS test server accepts a connection with a valid certificate.
- [ ] 2.2 Combine the client certificate with the self-signed option and the
  custom CA (`setTrustedCertificatesBytes`); verify a private-CA server is
  trusted and an unrelated certificate is rejected.
- [ ] 2.3 Map the per-server mTLS settings in the factory so every call path
  presents the certificate; verify the tag-fetch and upload paths also present it.

## 3. UI and localization

- [ ] 3.1 Add the "Client certificate (mTLS)" section to `config_dialog`
  (enable switch, file chooser, password field, remove/replace, custom CA) with
  PEM hidden where unsupported; verify manual configuration on Android.
- [ ] 3.2 Add validation and inline messages for invalid files and wrong
  passwords; verify saving is blocked and nothing is stored on invalid input.
- [ ] 3.3 Add the new strings to `app_en.arb` and `app_es.arb` and regenerate
  localizations; verify `flutter gen-l10n` and the app build succeed.

## 4. Error reporting

- [ ] 4.1 Extend the connection result and `testConnection` mapping with the
  certificate cases (wrong password, required-but-missing, expired/rejected) and
  a generic fallback; verify each case shows its message in the server form.
- [ ] 4.2 Verify that no certificate material or password is written to logs
  during a failing connection with debug logging enabled.

## 5. Tests

- [ ] 5.1 Add `file_selector` to `pubspec.yaml` and verify the app builds for
  Android.
- [ ] 5.2 Add throwaway test certificates (CA, server, client) plus a documented
  `openssl` generation script; verify the fixtures load in a test.
- [ ] 5.3 Add the end-to-end test: a Dart `SecureServerSocket` with
  `requestClientCertificate` accepts a connection with the certificate, rejects
  one without it, and rejects a wrong password; verify it passes locally.
- [ ] 5.4 Run `flutter test` and `flutter analyze` clean.

## 6. Documentation

- [ ] 6.1 Document mTLS setup in `README.md` (formats, per-platform notes,
  custom CA) and verify the instructions against the generated test fixtures.
