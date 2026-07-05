## 1. Model changes

- [ ] 1.1 Add `bool askTagsBeforeUpload` field to `ServerConfig` class with default `false`
- [ ] 1.2 Update `ServerConfig.copyWith()` to include `askTagsBeforeUpload`
- [ ] 1.3 Update `ServerConfig.toJson()` / `ServerConfig.fromJson()` to serialize/deserialize `askTagsBeforeUpload`
- [ ] 1.4 Update `ServerConfig.==` and `ServerConfig.hashCode` to include the new field

## 2. Configuration UI

- [ ] 2.1 Add a `SwitchListTile` or toggle in the tag configuration section of `config_dialog.dart` for "Ask for tags before upload"
- [ ] 2.2 Wire the toggle to `appConfigProvider` / `serverManager` to persist the boolean via `updateServer()`
- [ ] 2.3 Verify the toggle value is loaded correctly when opening the config dialog

## 3. Localization

- [ ] 3.1 Add ARB entries for the toggle label: `ask_tags_before_upload_title` and `ask_tags_before_upload_subtitle`
- [ ] 3.2 Add ARB entries for the per-upload dialog context (title, confirm button)
- [ ] 3.3 Run `flutter gen-l10n` to regenerate localization files
- [ ] 3.4 Add Spanish (`es`) translations for all new keys

## 4. Home screen upload flow

- [ ] 4.1 In `_processSharedBatch`, before the `uploadProvider.uploadFile()` call, check `appConfig.askTagsBeforeUpload`
- [ ] 4.2 If enabled, show `TagSelectionDialog` with `initialSelectedTagIds` set to current default tags
- [ ] 4.3 On dialog confirm: proceed with upload using the dialog-chosen tag IDs (pass to `uploadProvider`)
- [ ] 4.4 On dialog cancel: skip this file and continue to the next file in batch (or close activity if last)
- [ ] 4.5 Verify that the existing `uploadProvider.uploadFile()` can accept explicit tag IDs without reading from saved config (add optional parameter if needed)

## 5. Verification

- [ ] 5.1 Test upload with setting OFF: file uploads with saved default tags, no dialog appears
- [ ] 5.2 Test upload with setting ON: dialog appears pre-populated with defaults, can modify tags
- [ ] 5.3 Test dialog cancel: upload is aborted, saved defaults are unchanged
- [ ] 5.4 Test with multiple files in batch: dialog appears for each file
- [ ] 5.5 Build APK and verify on a real device
