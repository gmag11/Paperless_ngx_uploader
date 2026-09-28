# Design

## Context

The app is Flutter Android-only. File intake works today as follows:

- `AndroidManifest.xml` registers `SEND`/`SEND_MULTIPLE` (`*/*`) and `SEND` `text/plain` intent filters on the activity (single, `launchMode="singleTask"`).
- `MainActivity.kt` resolves the intent in `resolveShareIntent(...)`: `EXTRA_STREAM` → `copyUriToCache(...)` (copies `content://` to `cacheDir/shared_files`, returns local paths). On cold start it is captured in `onCreate` and on warm start in `onNewIntent`, emitting through the EventChannel `net.gmartin.paperlessngx_uploader/share_stream`. After capturing, the intent is replaced with `ACTION_MAIN` to avoid re-delivering after the activity is recreated.
- The Dart side (`lib/services/intent_handler.dart`) receives file paths or URLs, validates type/support and emits `ShareReceivedEvent(s)` towards the upload flow (including the optional tag prompt of `ask-tags-on-upload`).

`ACTION_VIEW` delivers the file as a URI in `intent.data`, not in `EXTRA_STREAM`. See `proposal.md` for the motivation and `specs/android-open-with/spec.md` for the behavior contract.

The project currently has no automated tests (neither `test/` in Dart nor `androidTest`/unit tests in Android); this change inaugurates the test harness.

## Goals / Non-Goals

**Goals:**
- Register the app in the "Open with" chooser only for supported types, without appearing for the rest.
- Reuse the existing intake pipeline: full parity with "Share with", extending the channel protocol only to propagate read failures (see D7).
- Preserve exactly-once delivery (current intent-cleanup pattern) also for `ACTION_VIEW`.
- Warn with a red toast about delivered files that cannot be read, using the existing notification mechanism (`UIHelper`).
- Leave the project's first set of automated tests, scoped to the new behavior (chooser registration, delivery via `ACTION_VIEW` and unreadable-file notice) and runnable without a device.

**Non-Goals:**
- Redesign of `IntentHandler`, of the MethodChannel/EventChannel protocol beyond the `{files, errors}` extension, or of the upload flow.
- Error handling beyond the notice: no retries, notice queue or persistent banners (a single notice per batch with the affected files).
- Changing the existing share filters, handling `http(s)` URLs via VIEW or iOS support.
- Tests of the existing Dart pipeline, of the tag prompt or of the end-to-end lifecycle of the Flutter activity (requires a device; remains in manual verification of the tasks).

## Decisions

1. **`ACTION_VIEW` intent filter with an explicit list of supported `android:mimeType`s** (`application/pdf`, `image/jpeg`, `image/png`, `image/tiff`, `image/gif`, `image/webp`) and `content` and `file` schemes, with `category.DEFAULT`.
   - *Why*: the user chose to offer the app only for supported types; with `image/*` or `*/*` it would appear for files that would then be marked as unsupported. `DEFAULT` (not `BROWSABLE`) prevents the app from competing when opening web links.
   - *Discarded alternative*: one filter per MIME type (more verbose, same result). A single filter with one `<data android:mimeType>` per type is preferred.

2. **Resolve `ACTION_VIEW` on the native side reusing `copyUriToCache`**, adding a branch in `resolveShareIntent` that reads `intent.data`. The resolution returns successes and failures (see D4) and is shared equally by `onCreate`, `onNewIntent` and the EventChannel.
   - *Why*: the Dart side already expects local paths with resolvable name/size; copying to cache when receiving the intent also avoids losing the temporary read permission of the `content://`. Full parity with "Share" because both flows share the same resolution.
   - *Discarded alternative*: passing the raw URI to Flutter and opening it there (forces managing persistable permissions and resolving name/size in Dart; no observable benefit).

3. **Exactly-once delivery reusing the current pattern**: after capturing the files of an `ACTION_VIEW`, the intent is replaced with `ACTION_MAIN` just as today with shares.
   - *Why*: it covers the activity-recreation scenario without new state to synchronize.
   - *Discarded alternative*: registering already-delivered URIs in memory/persistence (unnecessary, the current pattern already satisfies the spec).

4. **Read failure = skipping the file + visible red notice**. The resolver attempts reading uniformly for `content://` and `file://` and returns successes and failures instead of silently discarding: the unreadable file does not enter the upload pipeline (no crash, no upload, no false success) and its name is propagated to the UI for the notice (D7).
   - *Why*: silent discarding (previous behavior) left the user unaware that a file had not been uploaded; the requested red notice covers it by reusing the app's notification mechanism.
   - *Discarded alternative*: keeping the silent skip — it was the original decision of this design and is replaced by the requested visible feedback.

5. **JVM automated tests with Robolectric** in `android/app/src/test/`, run with `./gradlew :app:testDebugUnitTest`.
   - Cases: (a) intent resolution against the real merged manifest — `ACTION_VIEW` with `application/pdf` and the supported images resolves to the app's activity, `ACTION_VIEW` with an unsupported type does not resolve, `SEND`/`SEND_MULTIPLE` still resolve (regression) —; (b) the `ACTION_VIEW` branch of the resolver — readable `content://` returns a single cache path with the copied content, `file://` returns its path, unreadable source returns an empty list without throwing — and regression of simple/multiple `EXTRA_STREAM` and of URL in text.
   - *Why*: they run on the JVM without an emulator; Robolectric reads the module's real merged manifest and allows simulating the `ContentResolver`. It adds a single development dependency.
   - *Discarded alternatives*: instrumented (`androidTest` + `androidx.test`) — maximum fidelity but requires a device on every run —; `flutter test` — does not reach: the change is native and Dart is not modified —; both — unnecessary scope for what needs to be covered —.

6. **Extract intent resolution into a testable class** (e.g. `ShareIntentResolver`, functions over `Intent`/`ContentResolver`/cache dir) to which `MainActivity` delegates. Pure refactor, no behavior change.
   - *Why*: `resolveShareIntent`/`copyUriToCache` are private to the activity and testing `MainActivity` directly would start the Flutter engine on the JVM.
   - *Discarded alternative*: testing via `ActivityScenario` on the real activity (requires a device and starts the engine; fragile and slow).

7. **Propagate delivery failures to Dart and warn with the existing mechanism** (`UIHelper.showMessage(..., success: false)` → red Fluttertoast toast on mobile, with a SnackBar fallback), from `home_screen`, with a localized string naming the file(s).
   - Mechanism: the payload of `getInitialSharedFiles` and of the EventChannel changes from `List<String>` to `{files, errors}`; `IntentHandler` emits an event with the failed names and `home_screen` shows a single notice per batch. Both sides ship in the same APK, with no cross-compatibility to preserve.
   - *Why*: the failure occurs while copying the `content://` in Kotlin and must be carried up to the UI. Reusing `UIHelper` provides the requested red without a new mechanism, keeps the style of the rest of the notices and respects the current pattern (service emits events → screen paints).
   - *Discarded alternatives*: native `Toast` in Kotlin (`Toast.setView` for red is deprecated since API 30 and its style diverges from `UIHelper`); calling Fluttertoast directly from `IntentHandler` (would skip the screen→`UIHelper` pattern and its desktop fallback); an additional event channel only for errors (more moving parts for the same result); persistent SnackBar/banner with retry (more intrusive than a toast).

## Risks / Trade-offs

- [Some file managers declare a generic MIME (`application/octet-stream`) or unlisted types] → The app will not appear in "Open with" for those files; accepted by the supported-types-only decision. The user can still use "Share with" (`*/*` is kept).
- [The user expects a viewer when using "Open with" on an image/PDF] → The app uploads to Paperless instead of previewing; mitigated by the label name ("… Uploader") and because the upload flow confirms the action.
- [Name collisions in `copyUriToCache` (overwritten by `DISPLAY_NAME`)] → Preexisting limitation that the VIEW flow does not widen (a single file per intent); documented, not fixed here.
- ["Open with" chooser behavior varying by OEM/file manager] → Out of our control; entering via VIEW or via SEND the processing is identical, so the observable result is consistent.
- [Robolectric simulates `ContentResolver`/`PackageManager` by shadowing them] → The cases are limited to the real manifest (outside the simulation) and to explicitly registered streams; the manual sanity check on device (tasks 2.3 and 3.1) remains the final verification of the lifecycle.
- [Mismatch between Robolectric and the target SDK (36)] → Pin `@Config(sdk = …)` to a version supported by the chosen Robolectric version if execution requires it.
- [Exactly-once lifecycle not automated] → The intent-cleanup logic stays in the activity (outside the testable resolver) and is verified manually; automating it would require instrumented tests, discarded by scope.
- [Test scope creeping towards the Dart pipeline] → Bounded by explicit decision in Non-Goals: only the new behavior is automated.
- [The same notice is shown as a toast or as a SnackBar depending on platform and context] → It is the preexisting behavior of `UIHelper` and of the rest of the app's notices; consistent by construction.

## Migration Plan

No data or schemas to migrate. The change is manifest + native code + notices in Dart and is deployed as a normal app update; reverting the commit reverts the chooser registration. The suites are run with `./gradlew :app:testDebugUnitTest` (JVM) and `flutter test` (Dart), without a device or additional deployment steps.
