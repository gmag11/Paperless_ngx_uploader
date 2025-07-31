# Paperless-NGX Android Uploader App Specification

## Overview

- **Platform:** Flutter (latest version)
- **Compatibility:** Android 10+
- **Language:** English (translation-ready)
- **Purpose:** Upload files to Paperless-NGX via Android's native share intent (single file per action)

## Main Features

- **Configuration Dialog**
  - Server URL, username, password
  - Credentials stored securely
  - Connection status feedback (success, invalid credentials, unreachable host)

- **Tag Management**
  - Fetch tags from Paperless-NGX after successful connection
  - Tag selection dialog with search/filter
  - User can set default tags for uploads

- **File Upload**
  - Receives file document from Android share intent
  - Files are doc, pdf, image or other document types
  - Uploads document with selected/default tags
  - Shows upload result/status

## Architecture

```mermaid
flowchart TD
    A[Android Share Intent] --> B[App Receives File]
    B --> C[Check Server Config]
    C -->|Not Configured| D[Show Config Dialog]
    C -->|Configured| E[Try Connection]
    E --> F{Connection Status}
    F -->|Success| G[Fetch Tags]
    F -->|Fail| H[Show Error (user/pass/host)]
    G --> I[Show Tag Selection Dialog (search/filter)]
    I --> J[Upload File with Selected Tags]
    J --> K[Show Upload Result]
```

## UI Screens

- **Configuration Dialog:** Server, user, password, connection status
- **Tag Selection Dialog:** Search/filter, select default tags
- **Upload Status Screen:** Shows result of upload

## Constraints

- Single Paperless-NGX server support
- Secure credential storage
- One file upload per share action
- Simple, intuitive UI
