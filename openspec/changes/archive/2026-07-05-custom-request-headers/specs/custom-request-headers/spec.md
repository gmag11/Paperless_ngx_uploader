## ADDED Requirements

### Requirement: Per-server custom HTTP headers configuration
The system SHALL allow users to define an arbitrary list of custom HTTP header key-value pairs per Paperless-ngx server configuration and SHALL include those headers in every HTTP request sent to that server.

#### Scenario: User adds custom headers to a server
- **WHEN** a user configures a server and adds one or more custom headers (e.g., `P-Access-Token-Id: abc`, `P-Access-Token: xyz`)
- **THEN** the headers are persisted as part of the server configuration and survive app restart

#### Scenario: Custom headers are included in API requests
- **WHEN** the app sends any HTTP request to a Paperless-ngx server that has custom headers configured
- **THEN** every request (test connection, tag fetch, document upload, etc.) SHALL include all configured custom headers alongside the existing authorization headers

#### Scenario: Server with no custom headers configured
- **WHEN** a server has no custom headers defined (empty or null)
- **THEN** the app SHALL behave identically to the current implementation, with no extra headers added

#### Scenario: User removes a custom header
- **WHEN** a user edits a server configuration and removes a previously configured custom header
- **THEN** that header SHALL no longer be sent in subsequent requests to that server

### Requirement: Custom headers UI in server configuration
The server configuration dialog SHALL provide a section for managing custom headers with the ability to add, edit, and remove key-value pairs.

#### Scenario: Custom headers section is available
- **WHEN** a user opens the server configuration form (add or edit server)
- **THEN** a "Custom Headers" section is visible with an option to add header rows

#### Scenario: Adding a new header row
- **WHEN** a user clicks "Add header" in the custom headers section
- **THEN** a new row appears with key and value text input fields

#### Scenario: Removing a header row
- **WHEN** a user clicks the remove button on an existing header row
- **THEN** that row is removed from the form and its key-value pair SHALL NOT be saved

#### Scenario: Empty header key is rejected
- **WHEN** a user tries to save a server configuration with a custom header that has an empty key (but possibly a non-empty value)
- **THEN** validation SHALL reject the save and show an error indicating the empty key

### Requirement: Security and privacy of custom headers
Custom header values SHALL be treated with the same security considerations as authentication credentials.

#### Scenario: Custom header values not logged, keys allowed
- **WHEN** debug logging is enabled (kDebugMode)
- **THEN** custom header values SHALL NOT appear in log output, but header names (keys) MAY be logged for troubleshooting purposes

#### Scenario: Custom headers stored in secure storage
- **WHEN** a server configuration with custom headers is saved
- **THEN** the custom header keys and values SHALL be persisted in the same secure storage mechanism used for other server credentials
