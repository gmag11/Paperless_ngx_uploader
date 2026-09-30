# Spec Delta

## Purpose

Guarantees that every Paperless-NGX API request is sent through one centrally
configured HTTP transport, so per-server settings apply uniformly regardless of
which screen or flow triggered the request.

## ADDED Requirements

### Requirement: Single transport for Paperless-NGX traffic

All Paperless-NGX API requests (connection test, protocol detection, tag fetch,
tag dialog, document upload, and any future endpoint) SHALL be issued by a client
produced by the shared client factory, and no screen, widget, provider or service
outside that factory SHALL construct a Paperless-NGX client directly.

#### Scenario: Every call path uses the shared factory

- **WHEN** the app performs a Paperless-NGX request from any flow (connection
  test from the server form, protocol auto-detection, tag dialog, pre-upload tag
  fetch, or document upload)
- **THEN** the request is issued by a client produced by the shared factory and
  carries that server's complete transport configuration

#### Scenario: Direct construction is rejected by the guard

- **WHEN** the repository guard test scans `lib/` for Paperless-NGX client
  constructions
- **THEN** it finds them only in the factory (and in the factory's own tests), and
  fails otherwise

### Requirement: Uniform per-server transport configuration

The transport configuration of a server — authorization header, custom headers
and TLS trust policy (including the self-signed certificate option) — SHALL be
applied identically to every request to that server, on every call path, without
per-path exceptions.

#### Scenario: Custom headers are sent by previously-exempt paths

- **WHEN** a server has custom HTTP headers configured and the app fetches tags
  for the tag dialog, fetches tags before an upload, tests the connection after
  saving, or auto-detects the protocol
- **THEN** each of those requests includes the configured custom headers, exactly
  as `custom-request-headers` requires

#### Scenario: TLS trust policy applies to every path

- **WHEN** a server is configured to accept self-signed certificates
- **THEN** every request to that server (test, protocol detection, tag fetch, tag
  dialog, upload) accepts the self-signed certificate, and disabling the option
  makes every path reject it again

#### Scenario: The TLS policy belongs to the server being edited

- **WHEN** the user edits the self-signed certificate option while configuring a
  server that is not the currently selected one, or while adding a new server
- **THEN** the connection test and the saved configuration use the value shown in
  the form for that server, and the selected server's option is left unchanged

#### Scenario: Authorization is applied identically

- **WHEN** a server uses API-token authentication or username/password
  authentication
- **THEN** every request path sends the corresponding `Authorization` header and
  no path falls back to a different or missing authentication

### Requirement: Draft configuration testing uses the same transport rules

The system SHALL allow testing the connection and auto-detecting the protocol for
a configuration that has not been saved yet, applying the same transport rules as
a saved server.

#### Scenario: Protocol auto-detection for an unsaved server

- **WHEN** a user enters a server address without a protocol and taps "Save and
  test"
- **THEN** the app tries HTTPS first and then HTTP using the typed credentials,
  custom headers and TLS trust policy, and persists the protocol that connects

#### Scenario: Connection test for an unsaved server

- **WHEN** a user tests a server configuration before it is saved
- **THEN** the test uses the same authorization, custom headers and TLS trust
  policy that the saved server will use

### Requirement: Arbitrary shared-link downloads stay isolated

When the app downloads a document from an arbitrary URL obtained from a share
intent, it SHALL NOT send Paperless-NGX credentials, custom headers or client
certificates, because that URL is not a Paperless-NGX endpoint.

#### Scenario: Shared link is downloaded without Paperless transport settings

- **WHEN** the user shares an `http(s)` link that points to a document
- **THEN** the app downloads it without the selected server's authorization
  header, custom headers or client certificate
