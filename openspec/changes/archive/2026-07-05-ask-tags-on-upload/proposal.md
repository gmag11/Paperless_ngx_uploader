## Why

Users who upload documents with varying tag requirements need to change tags per-document without permanently modifying their default settings. Currently, tags are applied from a static server-level configuration, forcing the user to navigate to settings, change tags, upload, then change them back — or accept wrong tags and fix them later in Paperless-NGX web UI. Issue #13 captures this friction clearly.

## What Changes

- Add a boolean setting "Ask for tags before upload" (default: off) to server configuration.
- When enabled, the upload flow pauses before each upload to show a tag selection dialog pre-populated with the current default tags.
- User can confirm, modify, or cancel per-upload tags without altering saved defaults.
- The toggle is exposed alongside the existing tag configuration UI.
- **BREAKING**: None. The default behavior remains unchanged (no prompt, apply configured tags).

## Capabilities

### New Capabilities
- `ask-tags-on-upload`: Before uploading a shared file, optionally prompt the user to review and adjust tags for this specific upload without changing the persisted default tag selection.

### Modified Capabilities
<!-- None – existing tag behavior is fully preserved as the default. -->

## Impact

- **`lib/models/server_config.dart`**: New boolean field `askTagsBeforeUpload` (default `false`).
- **`lib/providers/server_manager.dart`**: Ensure the new field is serialized/deserialized.
- **`lib/screens/home_screen.dart`**: Intercept the upload flow when the setting is enabled, show `TagSelectionDialog`, pass chosen tags to `UploadProvider`.
- **`lib/widgets/tag_selection_dialog.dart`**: Already exists and can be reused as-is.
- **`lib/widgets/config_dialog.dart`**: Expose the toggle in the server/tag configuration UI.
- **Localization**: Add new strings for the toggle label and dialog context.
