# Ask Tags on Upload

## Purpose

Allow users to optionally review and adjust document tags before each upload without modifying their saved default tag configuration.

## Requirements

### Requirement: Toggle to enable per-upload tag prompt
The system SHALL expose a boolean setting "Ask for tags before upload" in the server/tag configuration UI. The setting SHALL default to `false`.

#### Scenario: Setting is off by default
- **WHEN** a new server is created or the setting has never been changed
- **THEN** `askTagsBeforeUpload` is `false` and uploads proceed without prompting

#### Scenario: User enables the setting
- **WHEN** user toggles "Ask for tags before upload" to ON in the configuration
- **THEN** the `askTagsBeforeUpload` flag is persisted in the server config and survives app restart

#### Scenario: User disables the setting
- **WHEN** user toggles "Ask for tags before upload" to OFF
- **THEN** `askTagsBeforeUpload` is persisted as `false` and the current default tags are used on upload without prompting

### Requirement: Tag selection dialog shown before upload
When the setting is enabled, the system SHALL present a tag selection dialog before each upload. The dialog SHALL be pre-populated with the current default tags from server configuration.

#### Scenario: Dialog opens before upload with setting enabled
- **WHEN** a file is shared to the app AND `askTagsBeforeUpload` is `true`
- **THEN** a `TagSelectionDialog` is shown with the current `defaultTagIds` pre-selected

#### Scenario: User confirms with selected tags
- **WHEN** user adjusts tags in the dialog and presses confirm/upload
- **THEN** the upload proceeds using the tags selected in the dialog (not the saved defaults)

#### Scenario: User cancels the dialog
- **WHEN** user dismisses or cancels the tag selection dialog
- **THEN** the upload is aborted and no file is sent to Paperless-NGX

### Requirement: Default tags remain unchanged after prompted upload
The saved default tag configuration SHALL NOT be modified by the per-upload tag selection.

#### Scenario: Tags chosen in dialog do not overwrite defaults
- **WHEN** user selects different tags in the prompt than their saved defaults AND confirms upload
- **THEN** the `defaultTagIds` in server config remain unchanged

#### Scenario: Setting disabled respects original behavior
- **WHEN** `askTagsBeforeUpload` is `false`
- **THEN** the upload flow SHALL behave identically to the current implementation (no prompt, apply `defaultTagIds` directly)
