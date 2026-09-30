# Proposal

## Why

Today the app only registers itself as a **"Share with"** (`ACTION_SEND`/`ACTION_SEND_MULTIPLE`) target on Android. When the user opens a compatible file (PDF, image) from a file manager, an email or Downloads, the **"Open with"** chooser never offers the app, so to send the document to Paperless-NGX the user has to go through the sharing menu of the app that opens it. Registering the app as an `ACTION_VIEW` handler allows files to be delivered to it directly from "Open with".

## What Changes

- Register `ACTION_VIEW` intent filters in `AndroidManifest.xml` for the types already supported by the app: `application/pdf`, `image/jpeg`, `image/png`, `image/tiff`, `image/gif`, `image/webp`, for `content://` and `file://` schemes. The app will appear in the "Open with" chooser only for those types.
- Extend the native intent resolution (`MainActivity.resolveShareIntent`) to handle `ACTION_VIEW`, whose file arrives as a URI in `intent.data` (not in `EXTRA_STREAM`), reusing the existing cache copy.
- Files received via "Open with" enter the **same intake pipeline** as shared ones (`ShareReceivedEvent` → upload flow): same optional tag selector, same unsupported-type warnings, same cold- and warm-start handling (`singleTask`/`onNewIntent`), with an exactly-once guard persisted in the saved instance state so a task recreated by the system does not re-deliver the file.
- Visible error notice (**red toast** with the app's `UIHelper` mechanism) when a delivered file — opened **or** shared — cannot be read and is skipped: the notice names the affected file and the rest of the batch continues. Read failures are propagated from the native code to Dart (channel payload extended to `{files, errors}`).
- Introduce the **project's first set of automated tests**, scoped to the behavior of this change: JVM tests with Robolectric on the "Open with" chooser registration and file delivery via `ACTION_VIEW`, and a Dart test for the unreadable-file notice.
- No new app dependencies (only a development dependency for tests).
- Update README/documentation to mention "Open with" in addition to "Share".

## Capabilities

### New Capabilities
- `android-open-with`: The app registers as an "Open with" target on Android for supported file types and processes the opened file through the existing intake pipeline, with behavioral parity with shared files, including the visible notice for files that cannot be read.

### Modified Capabilities
<!-- Empty: ask-tags-on-upload and the rest describe behavior of the upload flow,
     which is reused unchanged; intake parity is specified in the new capability. -->

## Impact

- `android/app/src/main/AndroidManifest.xml`: new `ACTION_VIEW` intent filters.
- `android/app/src/main/kotlin/net/gmartin/paperlessngx_uploader/MainActivity.kt`: intent resolution delegated to `ShareIntentResolver`, `ACTION_VIEW` support, reporting of read failures in the channel payload, buffering of warm-start payloads until Dart listens, and the saved-state exactly-once guard.
- `android/app/src/main/kotlin/net/gmartin/paperlessngx_uploader/ShareIntentResolver.kt` (new): resolution of `ACTION_VIEW`/`SEND`/`SEND_MULTIPLE`, uniform copy of `content://` and `file://` to cache, failure reporting and collision-free destination names.
- `android/app/src/main/kotlin/net/gmartin/paperlessngx_uploader/InitialIntentHandler.kt` (new): owns the launch intent and the exactly-once guard keyed on the intent identity.
- `android/app/src/test/` (new): JVM tests with Robolectric for manifest intent resolution, delivery via `ACTION_VIEW`, resolver behavior and the exactly-once guard.
- `android/app/build.gradle.kts`: development dependencies for tests (Robolectric) and JVM test configuration.
- `lib/services/intent_handler.dart` and `lib/screens/home_screen.dart`: consumption of delivery failures and red notice with `UIHelper.showMessage(..., success: false)`.
- `lib/l10n/app_en.arb` / `app_es.arb`: localized string for the unreadable-file notice.
- `test/` (new): Dart test for the unreadable-file notice.
- `README.md` / `docs/technical_design.md`: documentation of the new entry point, of the unreadable-files notice and of how to run the tests.
- No changes to the app dependencies, the Paperless-NGX REST API or the current sharing behavior.

## Non-goals

- iOS support (the project is Android-only; the iOS scaffold has no intent integration).
- Opening `http(s)` URLs via `ACTION_VIEW` (remains out; URLs still arrive only by sharing text).
- Modifying the existing share filters (`*/*` stays as today).
- Opening multiple files at once (`ACTION_VIEW` delivers a single file).
- Test coverage of the existing Dart pipeline or of the full on-device lifecycle: this change only automates the new behavior; the rest remains in manual verification.
