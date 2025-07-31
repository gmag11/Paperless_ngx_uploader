# Paperless-NGX Android Uploader App Specification

## Overview

- **Platform:** Flutter (latest version)
- **Compatibility:** Android 10+
- **Language:** English (translation-ready)
- **Purpose:** Upload files to Paperless-NGX via Android's native share intent (single file per action)

## Main Features

- **Configuration Dialog**
  - Server URL, username, password
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
  - Shows upload result/status andsends the aplication to background
  - If the upload fails, the user is notified with a snackbar message.

## Architecture

```mermaid
flowchart TD
    A[Android Share Intent] --> B[App Receives File]
    B --> C[Check Server Config]
    C -->|Not Configured| D[Show Config Dialog]
    C -->|Configured| E[Try Connection]
    E --> F{Connection Status}
    F -->|Success| G[Fetch Tags and Configure Default Tags (one-time)]
    F -->|Fail| H[Show Error (user/pass/host)]
    G --> J[Upload File with Default/Configured Tags]
    J --> K[Show Upload Result]
    K -->|Success| L[Send App to Background]
    K -->|Fail| M[Show Error Snackbar]
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
