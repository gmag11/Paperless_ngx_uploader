# Paperless-NGX Android Uploader App Specification

## Overview

- **Platform:** Flutter (latest version)
- **Compatibility:** Android 10+
- **Language:** English (translation-ready)
- **Purpose:** Upload files to Paperless-NGX via Android's native share intent (single file per action)

## Main Features

- **Configuration Dialog**
  - Server URL
  - Authentication method selector: Username/Password | API Token
  - Inputs by method:
    - Username/Password: username, password
    - API Token: token
  - Credentials stored securely and recovered on startup
  - Connection status feedback (success, invalid credentials, unreachable host)

- **Tag Management**
  - Fetch tags from Paperless-NGX after successful connection
  - Tag selection dialog with search/filter
  - User can set default tags for uploads
  - Do not ask for tags configuration. User will set them if needed.
  - Configured tags are stored in the app preferences and used for uploads.
  - Selected tags are recovered from storage on startup.
  - Tags selection dialog reflect the already selected tags.

- **File Upload**
  - Receives file document from Android share intent
  - Files are doc, pdf, image or other document types
  - Uploads document with selected/default tags
  - Shows upload result/status and sends the application to background
  - If the upload fails, the user is notified with a snackbar message.

## Authentication

- **Supported Methods**
  - Username/Password
  - API Token (generated in Paperless‑NGX)

- **Storage**
  - Server URL and selected authentication method are stored in app preferences.
  - Secrets (password or API token) are stored using secure storage and never logged.

- **Propagation**
  - On startup, the active auth method and credentials are loaded and applied to:
    - Connection checks
    - Tag fetching
    - Upload requests

- **HTTP Headers**
  - Username/Password: `Authorization: Basic base64(username:password)`
  - API Token: `Authorization: Token {api_token}`
  - Only one Authorization header is set based on the selected method.

- **Error Semantics**
  - 401/403: invalid credentials (for either method)
  - Network/DNS/timeout: unreachable host
  - UI should display method-appropriate error messages.

## Architecture

```mermaid
flowchart TD
    A[Android Share Intent] --> B[App Receives File]
    B --> C[Check Server Config]
    C -->|Not Configured| D[Show Config Dialog]
    C -->|Configured| E[Try Connection (using selected auth)]
    E --> F{Connection Status}
    F -->|Success| G[Fetch Tags and Configure Default Tags (one-time)]
    F -->|Fail| H[Show Error (invalid credentials/host)]
    G --> J[Upload File with Default/Configured Tags (auth applied)]
    J --> K[Show Upload Result]
    K -->|Success| L[Send App to Background]
    K -->|Fail| M[Show Error Snackbar]
```

## UI Screens

- **Configuration Dialog:** Server, authentication method selector, relevant credential fields, connection status
- **Tag Selection Dialog:** Search/filter, select default tags
- **Upload Status Screen:** Shows result of upload

## Constraints

- Single Paperless-NGX server support
- Secure credential storage (preferences for non-secrets, secure storage for secrets)
- One file upload per share action
- Simple, intuitive UI
