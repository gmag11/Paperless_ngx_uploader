# Spec Delta

## Purpose

Lets a user configure a client certificate per Paperless-NGX server so the app
can connect to servers that require mutual TLS, storing the material securely
and reporting certificate problems clearly.

## ADDED Requirements

### Requirement: Per-server client certificate configuration

The system SHALL let the user enable a client certificate independently for each
server, selecting the certificate material and, when required, its password. The
option SHALL default to disabled and SHALL NOT affect other servers.

#### Scenario: mTLS is disabled by default

- **WHEN** a new server is created
- **THEN** client-certificate use is disabled, no certificate material is stored
  for it, and connections behave as before

#### Scenario: Configuration is persisted per server

- **WHEN** the user enables the client certificate for a server, selects a file
  and enters a password, and saves
- **THEN** the settings and material are stored for that server and survive an
  app restart

#### Scenario: Servers are independent

- **WHEN** two servers are configured and only one has a client certificate
- **THEN** only requests to that server present a client certificate

### Requirement: Supported certificate formats

The system SHALL accept a PKCS#12 file (`.p12`/`.pfx`, containing certificate,
chain and private key) with a password on every supported platform, and SHALL
accept a PEM certificate chain together with a separate PEM private key only on
platforms where the runtime supports it. On platforms that support only PKCS#12,
the PEM option SHALL be unavailable and explained.

#### Scenario: PKCS#12 is accepted

- **WHEN** the user selects a valid `.p12`/`.pfx` file and enters the correct
  password
- **THEN** the configuration is accepted and the certificate is used for
  connections

#### Scenario: PEM is unavailable where unsupported

- **WHEN** the target platform supports only PKCS#12
- **THEN** the PEM option is hidden or disabled with an explanation, and the user
  can still configure a PKCS#12 certificate

#### Scenario: Invalid material is rejected

- **WHEN** the user selects a file that is not a valid certificate container or
  enters the wrong password
- **THEN** the configuration is rejected with a clear message and no unusable
  certificate material is stored

### Requirement: Client certificate is presented on every connection

When a server has a client certificate configured, the system SHALL present it
during the TLS handshake for every request to that server, on every call path
(connection test, protocol auto-detection, tag fetch, tag dialog and document
upload).

#### Scenario: A certificate-requiring server accepts the app

- **WHEN** a server requires a client certificate and the app has a valid one
  configured for it
- **THEN** the connection test succeeds and subsequent requests succeed

#### Scenario: Every call path presents the certificate

- **WHEN** the client certificate is enabled for a server
- **THEN** the connection test, protocol auto-detection, tag fetch, tag dialog and
  upload each present the certificate during the handshake

#### Scenario: Disabled means no certificate is presented

- **WHEN** the client certificate is disabled for a server
- **THEN** no client certificate is presented on any connection to that server

### Requirement: Removing or replacing the certificate

The user SHALL be able to remove the client certificate from a server, which
disables mTLS for it and deletes the stored material, and to replace it with new
material.

#### Scenario: Removing the certificate

- **WHEN** the user removes the client certificate from a server and saves
- **THEN** subsequent connections present no client certificate and the stored
  material and password are deleted

#### Scenario: Replacing the certificate

- **WHEN** the user selects a different certificate file for a server that
  already had one
- **THEN** subsequent connections use the new certificate and the previous
  material is no longer stored

### Requirement: Secure handling of certificate material

Certificate material and its password SHALL be treated as secrets: stored in the
secure storage mechanism used for server credentials (or an app-private file when
that backend cannot hold the payload), and never written to logs or to the
non-secret server configuration.

#### Scenario: Secrets are not logged

- **WHEN** debug logging is enabled
- **THEN** neither certificate material nor the certificate password appears in
  log output

#### Scenario: Material is not in the plain server configuration

- **WHEN** a server configuration is serialized
- **THEN** it contains only non-secret mTLS metadata (enabled, format) and never
  the certificate bytes or password

### Requirement: Custom CA certificate for server trust

The system SHALL let the user provide a custom CA certificate so a server signed
by a private certificate authority can be verified properly. When a custom CA is
configured, server certificate verification SHALL use it.

#### Scenario: Private-CA server is trusted

- **WHEN** a server presents a certificate signed by a private CA and the user has
  configured that CA certificate
- **THEN** the connection is verified successfully without disabling certificate
  validation

#### Scenario: An untrusted certificate is still rejected

- **WHEN** a server presents a certificate that is not signed by a configured CA
  and the self-signed option is off
- **THEN** the connection is rejected with a certificate error

### Requirement: Clear reporting of certificate problems

The system SHALL distinguish certificate-related connection failures from generic
network or server errors and SHALL present an actionable message for each: a
rejected certificate, an expired certificate, an incorrect certificate password,
and a server that requires a client certificate while none is configured.

#### Scenario: Wrong password is reported

- **WHEN** the stored certificate password does not decrypt the certificate
- **THEN** the app reports a certificate password problem rather than a generic
  network error

#### Scenario: Server requires a certificate that is missing

- **WHEN** the server requests a client certificate and none is configured for
  that server
- **THEN** the app reports that a client certificate is required

#### Scenario: Expired or rejected certificate is reported

- **WHEN** the presented client certificate is expired or refused by the server
- **THEN** the app reports a certificate problem identifying the likely cause
