# Tasks

## 1. Test harness and "Open with" registration

- [x] 1.1 Add in `android/app/src/main/AndroidManifest.xml` an `ACTION_VIEW` intent filter on the activity with `category.DEFAULT`, `content` and `file` schemes, and one `<data android:mimeType>` per supported type (`application/pdf`, `image/jpeg`, `image/png`, `image/tiff`, `image/gif`, `image/webp`); verify with `flutter build apk --debug` that it compiles and that the merged manifest contains the VIEW filters without touching the existing SEND filters
- [x] 1.2 Configure the JVM test harness in `android/app/build.gradle.kts` (Robolectric and JUnit4 as development dependencies, Android resources for unit tests) and add a smoke test; verify that `./gradlew :app:testDebugUnitTest` runs and passes it
- [x] 1.3 Add Robolectric intent-resolution tests against the real manifest: `ACTION_VIEW` with PDF and supported images resolves to the app's activity, `ACTION_VIEW` with an unsupported type (e.g. `text/plain`, `video/mp4`) does not resolve it, and `SEND`/`SEND_MULTIPLE` still resolve (regression); verify that `./gradlew :app:testDebugUnitTest` passes green
- [x] 1.4 Update the usage section of `README.md` to mention that compatible files can be delivered with "Open with" in addition to "Share", and verify that the text matches the behavior registered by the tests of 1.3

## 2. Delivery of opened files

- [x] 2.1 Extract `resolveShareIntent`/`copyUriToCache` from `MainActivity` into a testable class (e.g. `ShareIntentResolver`) with uniform reading of `content://` and `file://` that reports successes and failures, and add the `Intent.ACTION_VIEW` branch that reads `intent.data`; keep the current sending through the channels (only successful paths) and no changes in Dart; verify with `flutter build apk --debug` that it compiles and that the previous tests remain green
- [x] 2.2 Add JVM tests of the resolver: readable `content://` returns a single cache path with the copied content, readable `file://` returns its path, an unreadable source is reported as a failure (no path and no exception thrown), and regression of `SEND` (single and multiple `EXTRA_STREAM`) and of URL in text; verify that `./gradlew :app:testDebugUnitTest` passes green
- [x] 2.3 Verify on emulator/device the non-automatable lifecycle: cold start (the file enters the upload flow once), warm start (it enters once and the app comes to the foreground) and activity recreation after killing the process (does not re-deliver the same file), according to `specs/android-open-with/spec.md`
- [x] 2.4 Update `docs/technical_design.md` (intents/intake and tests section) describing the entry via `ACTION_VIEW`, its native resolution and how to run the suites, and verify that it reflects the code implemented in 2.1

## 3. Visible notice for unreadable files

- [x] 3.1 Extend the payload of `getInitialSharedFiles` and of the EventChannel to `{files, errors}` from `MainActivity`, consume the errors in `IntentHandler` emitting an event with the failed names, and show in `home_screen` a single notice per batch with `UIHelper.showMessage(..., success: false)` (red toast) using a new localized string in `app_en.arb`/`app_es.arb` that names the file(s); verify that `flutter analyze` reports no new errors
- [x] 3.2 Add a Dart test (`flutter test`) of the notice: a batch with errors emits the event with the affected names, the readable files keep being emitted normally and a fully readable batch does not emit a notice; verify that `flutter test` passes green
- [x] 3.3 Verify on device the red notice: delivering an unreadable file via "Open with" and via "Share" shows the red toast naming the file without starting the upload, and in a partial batch the readable ones continue while a single notice identifies the unreadable ones (behavior of `specs/android-open-with/spec.md`)
- [x] 3.4 Document the notice in `README.md` and `docs/technical_design.md` (what the user sees and how the error is propagated up to `UIHelper`) and verify that it matches what was observed in 3.3

## 4. Integration verification

- [x] 4.1 Verify flow parity with "Share with" on device: an opened file receives the same treatment as a shared one — tag prompt with `ask-tags-on-upload` enabled (confirm/cancel just like in shares), default tags with the prompt disabled, and the red unreadable-file notice also in the share flow; contrast with `specs/android-open-with/spec.md`
- [x] 4.2 Verify global regression: sharing one and several files (`SEND`/`SEND_MULTIPLE`) and sharing a URL in text still work exactly as before, `flutter analyze` reports no new errors and `./gradlew :app:testDebugUnitTest` and `flutter test` finish green

## 5. Review fixes

- [x] 5.1 Exactly-once delivery: replace the sole reliance on `setIntent(ACTION_MAIN)` with `InitialIntentHandler`, which persists the identity of the handled intent in the activity's saved instance state so a task recreated after a system-initiated process death does not resolve and upload the launch intent again, while a different launch intent is still handled; add JVM tests for single capture, recreation with saved state, a different intent and launch intents without content
- [x] 5.2 Prevent double processing in Dart: keep pending initial events only when no batch listener is attached yet, and cover it with a `flutter test` case (`consumePendingBatch` stays empty after a stream delivery)
- [x] 5.3 Do not drop a warm-start file when the native event listener does not exist yet: buffer payloads in `MainActivity` and flush them on `onListen`
- [x] 5.4 Copy `file://` sources to the cache as well and give colliding destinations a unique name within a batch; update/extend the JVM resolver tests
- [x] 5.5 Re-verify on device the recreation after a system-initiated process death and a warm-start file arriving before the UI is ready (non-automatable lifecycle) — verified by the maintainer
- [x] 5.6 Keep the share cache bounded: `ShareIntentResolver.pruneStaleCache()` removes copies older than 24 h on app start, with a JVM test; keep the `file` scheme in the `ACTION_VIEW` filter as legacy coverage
