# Design

## Context

See `proposal.md` for motivation, and `centralize-http-client` for the transport
this change plugs into. Relevant facts established while exploring:

- `dart:io` `SecurityContext` supports `useCertificateChain(path|bytes, {password})`,
  `usePrivateKey(path|bytes, {password})` and `setTrustedCertificates(path|bytes,
  {password})`. Both PEM and PKCS#12 are accepted by the runtime.
- The SDK documents that **iOS supports only PKCS#12**, and that on iOS a single
  `usePrivateKey` call carries both key and chain (`useCertificateChain` is a
  no-op there).
- `PaperlessService` currently wires TLS through
  `(dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient`, creating a
  plain `HttpClient()` and setting `badCertificateCallback` when the self-signed
  option is on. That is the single hook where a `SecurityContext` must be
  attached.
- `SecureStorageService` is a string key/value store. It already keeps secrets
  under per-server keys (`server_<id>_password`, `server_<id>_api_token`) and
  serializes `ServerConfig` to JSON in the same store. On Linux, when the system
  keyring is unavailable, it silently falls back to `SharedPreferences`.
- The project targets Android; the iOS/desktop scaffolds exist, web is not a
  build target (`dart:io` is imported unconditionally).
- There is no file-picking dependency today.

## Goals / Non-Goals

**Goals:**
- Configure, store, present and remove a client certificate per server.
- Reuse the single transport from `centralize-http-client` so mTLS applies to
  every call path by construction.
- Keep secrets out of logs and out of the non-secret configuration.
- Make failures diagnosable and verify the feature end-to-end without a device.

**Non-Goals:**
- Hardware-backed keys, PKCS#11, smartcards, or key generation.
- Changing the self-signed switch semantics beyond combining with the new options.
- Applying certificates to arbitrary shared-link downloads.

## Decisions

1. **PKCS#12 is the primary format; PEM is supported where the runtime allows it.**
   PKCS#12 bundles certificate, chain and key behind one password and is the only
   portable option (iOS), so a single `.p12`/`.pfx` + password is the default path.
   PEM (certificate chain file + separate private-key file) is offered on
   platforms whose runtime supports it and hidden where not.
   - *Why*: one well-supported path plus an ergonomic alternative for desktop
     users, without inventing a parser.
   - *Discarded alternatives*: PKCS#12 only (forces PEM users on desktop to
     convert) — rejected as unnecessarily restrictive; parsing containers
     ourselves — rejected because `dart:io` already does it.

2. **Build one `SecurityContext` and attach it via `createHttpClient`.** Load the
   material with `useCertificateChainBytes` + `usePrivateKeyBytes` (PKCS#12 may be
   loaded through either call; on iOS the single `usePrivateKeyBytes` carries both),
   then create `HttpClient(context: ctx)`. Combine with the existing policy in the
   same hook: when the self-signed option is on, set `badCertificateCallback` on
   that client; when a custom CA is configured, add it via
   `setTrustedCertificatesBytes`.
   - *Why*: it is the existing, already-used hook, and it keeps all TLS policy in
     one place.
   - *Discarded alternative*: dio's `validateCertificate` alone — it checks the
     leaf after the handshake and cannot present a client certificate, so it
     cannot replace the `SecurityContext` wiring; it may be used only as an extra
     leaf check if needed.

3. **Custom CA instead of blind acceptance, layered with the existing switch.**
   A configured CA is added to the context's trusted certificates, so a
   private-CA server verifies normally. The existing "allow self-signed" switch
   keeps its meaning for the no-CA case. A CA is **required** metadata when the
   user wants verification against a private CA but does not want global
   self-signed acceptance.
   - *Why*: mTLS with a privately-signed server otherwise forces the blunt
     `badCertificateCallback = true`, which contradicts the point of mTLS.
   - *Discarded alternative*: keep only the self-signed switch — leaves private-CA
     users with a strictly worse security posture.

4. **Secrets are stored under dedicated per-server keys, not in `ServerConfig`.**
   `ServerConfig` gains only non-secret metadata (enabled, format, whether a
   custom CA is set); certificate bytes (base64) and the password go to
   `SecureStorageService` under `server_<id>_client_cert`, `..._client_key`,
   `..._client_cert_password`, `..._ca_cert`, consistent with existing credential
   keys.
   - *Why*: matches how password/token are already handled and keeps the
     serialized configuration non-secret.
   - *Discarded alternative*: store material inside the `ServerConfig` JSON — it
     would spread secrets into the general configuration blob and every log/print
     of it.

5. **Storage fallback honors the platform's limits and the plaintext risk.** The
   material is written to secure storage; if the backend rejects the payload (for
   example a Windows credential entry size limit) it is written to an app-private
   file and only a reference is stored. Crucially, certificate material MUST NOT
   use the `SharedPreferences` fallback that `SecureStorageService` uses when the
   Linux keyring is unavailable; for certificate material that fallback is
   replaced by the app-private file.
   - *Why*: the Linux fallback writes plaintext to preferences, which is
     acceptable for a password already governed by the same trade-off but not for
     adding large secret blobs; and some backends simply cannot hold the bytes.
   - *Discarded alternative*: always file-based (weaker on mobile where secure
     storage works well); always secure storage (breaks on size-limited backends).

6. **File selection uses `file_selector` (official Flutter plugin).** The picked
   file is read into bytes immediately and persisted by us; the picker's
   temporary path (Android SAF cache copy) is never relied on afterwards.
   - *Why*: maintained by flutter.dev, supports Android and desktop; reading
     bytes immediately removes the Android cache-lifetime problem.
   - *Discarded alternatives*: `file_picker` (also viable, larger surface);
     platform channels (too costly for the benefit).

7. **Certificate problems get first-class connection outcomes.** Extend the
   connection-result handling (the `ConnectionStatus` enum and the `testConnection`
   error mapping) with certificate-specific cases: password/decryption failure,
   required-but-missing, expired/rejected. Detection combines the structured
   `HandshakeException`/TLS alert with a best-effort message inspection, with a
   generic "certificate problem" as the fallback when the platform does not expose
   a precise reason.
   - *Why*: the issue reporter needs to know whether to fix the password, supply a
     certificate, or renew an expired one; a single "SSL error" is not actionable.
   - *Discarded alternative*: one generic SSL error — cheapest but poor UX.

8. **Platform gating follows the project's real targets.** The feature is offered
   on Android (primary) and on the desktop/iOS scaffolds that `dart:io` supports;
   on iOS only PKCS#12 is offered. Web is out of scope.
   - *Why*: matches `README` ("Android is the target platform") and avoids
     specifying behavior for a target that does not build.

9. **End-to-end verification with a Dart TLS server requiring a client
   certificate.** A `flutter test` starts a `SecureServerSocket` (with
   `requestClientCertificate: true` and a context trusting the test client CA),
   serves a minimal `/api/profile/`, and points `PaperlessService` at it.
   Throwaway test certificates (CA, server, client) are checked in under
   `test/fixtures/` and generated by a documented `openssl` script.
   - *Why*: exercises the real handshake (present / not present / wrong password)
     with no device, no Docker and no external server.
   - *Discarded alternatives*: nginx/docker-compose integration (heavier, needs a
     daemon); a device/emulator against a real mTLS server (not CI-friendly).

10. **Each artifact can be provided from a file or pasted as text, chosen per
    artifact.** A "File | Paste" selector switches the input for the certificate,
    the private key and the custom CA independently. Pasted PEM is stored as its
    UTF-8 bytes; pasted PKCS#12 is base64-decoded. Validation decodes the text and
    rejects anything that is not valid PEM or valid base64 before anything is
    stored.
    - *Why*: material frequently arrives as text (email, password manager, `cat`),
      and requiring a file is awkward on mobile; PEM is text and PKCS#12 is
      commonly distributed as base64, so both are covered. A per-artifact selector
      avoids the ambiguity of "which source wins".
    - *Discarded alternative*: a single always-visible paste field where pasted
      content silently overrides the file (less predictable); a combined
      certificate+key paste field (convenient, but conflates two artifacts and
      complicates the PEM/PKCS#12 distinction).

11. **Backward compatibility: additive and off by default.** No stored data
    changes shape; new keys are added only when the user configures a
    certificate. Existing servers keep working unchanged.

12. **The section collapses to its enable switch, and the custom CA is part of the
    mTLS configuration.** While the option is disabled, the form shows only the
    enable switch: no format selector, no input (file or paste) for the
    certificate, private key or custom CA, no password field and no remove button.
    Enabling it reveals them. Disabling it clears the custom CA in the form, and
    saving with it disabled deletes the stored custom CA along with the rest of
    the material.
    - *Why*: the certificate controls only make sense while mTLS is enabled, and
      leaving the custom-CA row visible (it has its own File/Paste controls) made
      the disabled section still look like it offered certificate input.
    - The custom CA lives in a collapsed **"Advanced"** subsection so it does not
      compete with the essential certificate fields (which PEM makes more
      numerous: a separate certificate and private key).
    - *Trade-off*: a custom CA can no longer be configured on its own, without a
      client certificate. If that case is ever needed, the CA belongs next to the
      "allow self-signed certificates" trust switch instead of inside this
      section; that is out of scope here.

## Risks / Trade-offs

- [iOS supports only PKCS#12] → PEM is hidden on iOS with an explanation; PKCS#12
  is the default path everywhere.
- [Windows secure storage cannot hold multi-KB secrets] → fall back to an
  app-private file for the material, keeping only a reference in secure storage.
- [Linux keyring fallback writes to plaintext preferences] → certificate material
  is explicitly excluded from that fallback and uses the app-private file instead;
  documented as a deliberate trade-off.
- [TLS failure reasons are not uniformly exposed by the platform] → certificate
  error mapping is best-effort with a clear generic certificate message as
  fallback; the spec requires the four main cases, not a precise alert code.
- [Combining a client certificate with `badCertificateCallback` can mask server
  misconfiguration] → the custom CA option is the recommended path and is
  validated; the self-signed switch remains explicit and user-controlled.
- [Test certificates checked into the repository] → they are throwaway, clearly
  named, and only usable against the in-process test server.
- [New dependency (`file_selector`)] → official plugin, native platforms already
  targeted; no web support needed.
- [Storing a password alongside the certificate] → same secure-storage mechanism
  as existing credentials; never logged.

## Migration Plan

Additive app update; no data migration (new keys created on first configuration,
default off). Rollback: reverting the commit disables the feature; any stored
material under the new keys is simply unused and can be left or cleaned by the
existing server-removal path, which will be extended to delete the new keys.

## Open Questions

- The exact app-private directory and file permissions used by the fallback can
  be validated during implementation per platform without affecting the specs or
  the task breakdown.
