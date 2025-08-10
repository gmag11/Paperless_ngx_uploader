# Paperless‑NGX Android Uploader

Flutter application for Android that uploads documents to Paperless‑NGX directly from the system Share menu. This project updates and adapts the original "Paperless Share" by qcasey to modern Android versions while keeping the same simple "share and upload" workflow.

Origin project: Paperless Share — <https://github.com/qcasey/paperless_share>  
This repository is an updated/re‑implemented version inspired by that project, using Flutter and current Android support.

![Screenshot_2025-08-09-15-40-28-450_net gmartin paperlessngx_uploader-edit](https://github.com/user-attachments/assets/54182f13-1bd1-45b6-82c5-8033bc0a2f3b)

## Features

- Android native Share Intent integration (supports multiple files in a single action).
- Paperless‑NGX server configuration (URL), username and password.
- Secure credential storage with automatic recovery on startup.
- Connection test with feedback (success, invalid credentials, unreachable host).
- Tag management:
  - Fetches tags from Paperless‑NGX after a valid connection.
  - Tag selection dialog with search/filter.
  - Option to set default tags for uploads.
  - Selected tags are persisted and restored on startup.
- Uploads shared documents with the configured/default tags.
- Upload status indicator; on failure, a Snackbar notifies the user.
- On success, the app returns to background.

Compatibility: Android 10+  
Platform: Flutter (multi‑platform scaffold present; Android is the target platform)

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
git clone https://github.com/USER_OR_ORG/paperless_ngx_android_uploader.git
cd paperless_ngx_android_uploader
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

## First‑time configuration

When opening/using the app for the first time:

- Enter the server URL (including protocol, e.g., <https://paperless.example.tld>).
- Enter Paperless‑NGX username and password.
- Alternatively, if your Paperless‑NGX instance uses OpenID login, you can provide an access token instead of username/password.
- Tap "Test connection". You'll see one of:
  - Success: credentials stored, tags fetched.
  - Invalid credentials: check username/password or access token.
  - Unreachable host: verify URL or network.
- Optionally select default tags. The selection is saved and restored on startup.

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
  - Main activity: [`MainActivity.kt`](android/app/src/main/kotlin/com/example/paperless_ngx_android_uploader/MainActivity.kt)
  - Share receiver: [`ShareReceiverActivity.kt`](android/app/src/main/kotlin/com/example/paperless_ngx_android_uploader/ShareReceiverActivity.kt)
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

- Supports a single Paperless‑NGX server.
- Multiple files per share action.
- Simple, focused UI to complete uploads quickly.

## Roadmap / TODO

- [X] Add support for token-based login for instances using OpenID login (accept user-provided access token and use it for API calls).
- [X] Implement multiple file upload.
- [ ] Publish app to F-Droid and/or Google Play Store.

## Credits and license

- Inspired by "Paperless Share" by qcasey: <https://github.com/qcasey/paperless_share>
- This project modernizes that idea for current Android versions and the Flutter ecosystem.

License: GNU General Public License v3.0 (GPL-3.0)
