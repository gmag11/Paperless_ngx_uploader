## 1. Model changes

- [x] 1.1 Add `bool askTagsBeforeUpload` field to `ServerConfig` class with default `false`
- [x] 1.2 Update `ServerConfig.copyWith()` to include `askTagsBeforeUpload`
- [x] 1.3 Update `ServerConfig.toJson()` / `ServerConfig.fromJson()` to serialize/deserialize `askTagsBeforeUpload`
- [x] 1.4 Update `ServerConfig.==` and `ServerConfig.hashCode` to include the new field

## 2. Configuration UI

- [x] 2.1 Add a `SwitchListTile` or toggle in the tag configuration section of `config_dialog.dart` for "Ask for tags before upload"
- [x] 2.2 Wire the toggle to `appConfigProvider` / `serverManager` to persist the boolean via `updateServer()`
- [x] 2.3 Verify the toggle value is loaded correctly when opening the config dialog

## 3. Localization

- [x] 3.1 Add ARB entries for the toggle label: `ask_tags_before_upload_title` and `ask_tags_before_upload_subtitle`
- [x] 3.2 Add ARB entries for the per-upload dialog context (title, confirm button)
- [x] 3.3 Run `flutter gen-l10n` to regenerate localization files
- [x] 3.4 Add Spanish (`es`) translations for all new keys

## 4. Home screen upload flow

- [x] 4.1 In `_processSharedBatch`, before the `uploadProvider.uploadFile()` call, check `appConfig.askTagsBeforeUpload`
- [x] 4.2 If enabled, show `TagSelectionDialog` with `initialSelectedTagIds` set to current default tags
- [x] 4.3 On dialog confirm: proceed with upload using the dialog-chosen tag IDs (pass to `uploadProvider`)
- [x] 4.4 On dialog cancel: skip this file and continue to the next file in batch (or close activity if last)
- [x] 4.5 Verify that the existing `uploadProvider.uploadFile()` can accept explicit tag IDs without reading from saved config (add optional parameter if needed)

## 5. Verification

- [x] 5.1 Test upload with setting OFF: file uploads with saved default tags, no dialog appears
- [x] 5.2 Test upload with setting ON: dialog appears pre-populated with defaults, can modify tags
- [x] 5.3 Test dialog cancel: upload is aborted, saved defaults are unchanged
- [x] 5.4 Test with multiple files in batch: dialog appears for each file
- [x] 5.5 Build APK and verify on a real device
