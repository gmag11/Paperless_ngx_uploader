# Paperless‑NGX Android Uploader

Flutter application for Android that uploads documents to Paperless‑NGX directly from the system Share menu. This project updates and adapts the original "Paperless Share" by qcasey to modern Android versions while keeping the same simple "share and upload" workflow.

**Origin project**: Paperless Share — <https://github.com/qcasey/paperless_share>
This repository is an updated/re‑implemented version inspired by that project, using Flutter and current Android support.

<p align="center">
  <a href="https://shields.rbtlog.dev/net.gmartin.paperlessngx_uploader">
    <img src="https://shields.rbtlog.dev/simple/net.gmartin.paperlessngx_uploader" alt="RB shield" />
  </a>
  <a href="https://apt.izzysoft.de/packages/net.gmartin.paperlessngx_uploader">
    <img src="https://img.shields.io/endpoint?url=https://apt.izzysoft.de/fdroid/api/v1/shield/net.gmartin.paperlessngx_uploader" alt="IzzyOnDroid" />
  </a>
  <a href="https://github.com/gmag11/Paperless_ngx_uploader/releases/latest">
    <img alt="GitHub Release" src="https://img.shields.io/github/v/release/gmag11/Paperless_ngx_uploader">
  </a>
  <a href="https://github.com/gmag11/Paperless_ngx_uploader/releases/latest">
    <img alt="GitHub Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/gmag11/Paperless_ngx_uploader/build-release-apks.yml">
  </a>
</p>

<p align="center">
  <a href="https://apt.izzysoft.de/packages/net.gmartin.paperlessngx_uploader">
    <img src="https://gitlab.com/IzzyOnDroid/repo/-/raw/master/assets/IzzyOnDroid.png" alt="Get it on IzzyOnDroid" height="80" />
  </a>
</p>

## Screenshots

<div>
    <img src="https://raw.githubusercontent.com/gmag11/Paperless_ngx_uploader/main/fastlane/metadata/android/en-US/images/phoneScreenshots/01.jpg" alt="Screenshot 1" width="160" style="margin-right:8px" />
    <img src="https://raw.githubusercontent.com/gmag11/Paperless_ngx_uploader/main/fastlane/metadata/android/en-US/images/phoneScreenshots/02.jpg" alt="Screenshot 2" width="160" style="margin-right:8px" />
    <img src="https://raw.githubusercontent.com/gmag11/Paperless_ngx_uploader/main/fastlane/metadata/android/en-US/images/phoneScreenshots/03.jpg" alt="Screenshot 3" width="160" style="margin-right:8px" />
    <img src="https://raw.githubusercontent.com/gmag11/Paperless_ngx_uploader/main/fastlane/metadata/android/en-US/images/phoneScreenshots/04.jpg" alt="Screenshot 4" width="160" />
</div>

## Features

- Android native Share Intent integration (supports multiple files in a single action).
- **Multiple Paperless‑NGX server profiles:** Add, edit, and switch between multiple server configurations, each with independent credentials and default tags.
- Secure credential storage with automatic recovery on startup.
- Connection test with feedback (success, invalid credentials, unreachable host).
- Tag management per server:
  - Fetches tags from the active Paperless‑NGX server after a valid connection.
  - Tag selection dialog with search/filter.
  - Option to set default tags for uploads (specific to each server profile).
  - Selected tags are persisted per server and restored on startup.
- Uploads shared documents with the configured/default tags of the selected server.
- Upload status indicator; on failure, a Snackbar notifies the user.
- On success, the app returns to background.

Compatibility: Android 10+
Platform: Flutter (multi‑platform scaffold present; Android is the target platform)

## Update Checks and Installer Source

The app automatically disables GitHub version checking if it is installed from the Play Store or F-Droid.

**Rationale:** Users who install from official stores receive updates through those channels, so in-app update checks are unnecessary for them.

No user action is required; this logic is automatic.

## How it works

1. From any app that supports sharing (PDF viewer, gallery, file manager), share one or more documents and choose "Paperless‑NGX Android Uploader".
2. On first use, configure the server URL, username and password; the app stores them securely.
3. The app tests the connection and downloads available tags from your Paperless‑NGX server.
4. Select any default tags you want to apply.
5. The app uploads all shared files with the selected tags and shows the result.

Notes:

- Multiple files can be uploaded in a single share action.
- Tag configuration is optional. You can upload without changing tags and set them later if needed.

## Requirements

- A reachable Paperless‑NGX server (API docs: <https://docs.paperless-ngx.com/api/>).
- Android 10 or newer.
- Network connectivity to the server.

## Installation (from source)

1) Prerequisites:

- Flutter installed and on PATH (stable and up to date).
- Android SDK/Android Studio (with an emulator or a physical device).

2) Clone the repository:

```bash
git clone https://github.com/gmag11/Paperless_ngx_uploader.git
cd Paperless_ngx_uploader
```

3) Get dependencies and run:

```bash
flutter pub get
flutter run -d android
```

4) Build APK (optional):

```bash
flutter build apk --release
```

The APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

## Server Management and Multi‑Server Support

You can use multiple Paperless‑NGX servers within the app. Each server has its own profile, credentials, and default tag configuration.

**How it works:**

- When opening the app, you can add multiple servers, each with its own URL, authentication (username/password or token), and tags.
- Switch between servers using the server manager dialog; the selected server becomes active for uploads and tag fetching.
- All credentials and tag selections are stored securely and separately for each server.
- You can edit or remove server profiles at any time.

## First‑time configuration

When opening/using the app for the first time:

- Add one or more Paperless‑NGX server profiles by providing the server URL (including protocol, e.g., <https://paperless.example.tld>).
- For each server, enter the username and password, or—if your Paperless‑NGX instance uses OpenID—an access token.
- Tap "Test connection". You'll see one of:
  - Success: credentials stored, tags fetched.
  - Invalid credentials: check username/password or access token.
  - Unreachable host: verify URL or network.
- Optionally select default tags for each server. Each server's tag selection is saved and restored independently.

The app will not repeatedly prompt for tags; configure them when convenient.

## Usage

1. In another app, choose "Share".
2. Select one or more files to share.
3. Select "Paperless‑NGX Uploader".
4. The app uses your configuration and default tags to upload all selected documents.
5. Check the upload status:
   - Success: the app returns to background.
   - Error: a Snackbar message explains the issue.

## Permissions

- Access to the shared files via the Android Share Intent.
- Network access to communicate with the Paperless‑NGX server.

No unrelated device resources are accessed.

## Security

- Credentials are stored securely and restored on startup.
- HTTPS is strongly recommended for the Paperless‑NGX server.
- Keep both your server and this app up to date.

## Troubleshooting

- "Invalid credentials": recheck username/password in settings.
- "Server unreachable" or timeout: verify URL, network, or TLS certificates.
- "Upload failed": check file size/type limits and server status, then retry.
- Tags don't appear: ensure the connection test succeeded and your user has the necessary permissions.

## Development

- Main Flutter/Dart code under `lib/`
  - Entry and screens: [`main.dart`](lib/main.dart), [`home_screen.dart`](lib/screens/home_screen.dart)
  - Models: [`connection_status.dart`](lib/models/connection_status.dart), [`tag.dart`](lib/models/tag.dart)
  - State (providers): [`app_config_provider.dart`](lib/providers/app_config_provider.dart), [`upload_provider.dart`](lib/providers/upload_provider.dart)
  - Services: [`intent_handler.dart`](lib/services/intent_handler.dart), [`paperless_service.dart`](lib/services/paperless_service.dart), [`secure_storage_service.dart`](lib/services/secure_storage_service.dart)
  - UI widgets: [`config_dialog.dart`](lib/widgets/config_dialog.dart), [`tag_selection_dialog.dart`](lib/widgets/tag_selection_dialog.dart)
- Android integration / Share Intent:
  - Main activity: [`MainActivity.kt`](android/app/src/main/kotlin/net/gmartin/paperlessngx_uploader/MainActivity.kt)
  - Share receiver: [`ShareReceiverActivity.kt`](android/app/src/main/kotlin/net/gmartin/paperlessngx_uploader/ShareReceiverActivity.kt)
  - Manifest: [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)
- Additional docs:
  - Technical design: [`technical_design.md`](docs/technical_design.md)
  - Localization guide: [`localization_guide.md`](docs/localization_guide.md)

Run in development:

```bash
flutter pub get
flutter run -d android
```

Formatting/linting:

- Follow Flutter/Dart guidelines. Use `dart format` and `flutter analyze`.

## Scope and status

- Supports multiple Paperless‑NGX servers (multi-server mode).
- Multiple files per share action.
- Simple, focused UI to complete uploads quickly.

## Roadmap / TODO

- [X] Add support for token-based login for instances using OpenID login (accept user-provided access token and use it for API calls).
- [X] Implement multiple file upload.
- [X] Add support for self-signed certificates.
- [X] Publish app to F-Droid
- [ ] Publish app to Google Play Store.

## Credits and license

- Inspired by "Paperless Share" by qcasey: <https://github.com/qcasey/paperless_share>
- This project modernizes that idea for current Android versions and the Flutter ecosystem.

License: GNU General Public License v3.0 (GPL-3.0)
