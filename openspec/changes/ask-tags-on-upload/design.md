## Context

Currently, tag selection is static: each server stores a list of `defaultTagIds` that are applied to every upload without user interaction. The user must navigate to the home screen tag section to change defaults before uploading, then revert manually.

The existing `TagSelectionDialog` widget already supports:
- Fetching all tags from Paperless-NGX API
- Multi-selection with search filtering
- Returning selected tag IDs via callback

The upload flow in `home_screen.dart` (`_processSharedBatch`) iterates over files and delegates to `uploadProvider.uploadFile()` / `uploadProvider.uploadUrl()`, which reads tags from `appConfigProvider.getSelectedTags()`.

## Goals / Non-Goals

**Goals:**
- Add a per-server boolean flag `askTagsBeforeUpload` defaulting to `false`.
- When `true`, intercept the batch processing loop to show `TagSelectionDialog` before the upload call.
- Pass dialog-chosen tags to the upload instead of the saved defaults.
- Preserve backward compatibility: default behavior is unchanged.

**Non-Goals:**
- Multiple tag profiles.
- Per-document storage of used tags.
- Changing the `TagSelectionDialog` API or UI.
- Time-based suppression of the prompt.

## Decisions

### 1. Store flag on `ServerConfig` rather than a separate SharedPreferences key
**Rationale:** Tags are already per-server in `ServerConfig.defaultTagIds`. Keeping the flag alongside tags in the same model avoids sync issues and simplifies serialization (`copyWith` / `toJson` / `fromJson`). No additional migration needed.

### 2. Intercept in `_processSharedBatch` rather than in `UploadProvider`
**Rationale:** The upload provider is a pure business-logic layer that shouldn't know about dialogs or UI. The home screen already orchestrates the batch flow, shows toasts, and has access to `BuildContext` for dialog display. Adding a conditional dialog before `uploadProvider.uploadFile()` is the least invasive change.

### 3. Reuse existing `TagSelectionDialog` without modification
**Rationale:** The dialog already accepts `initialSelectedTagIds` and returns selected IDs via callback. The only adaptation needed is passing the dialog result as parameter to the upload call.

### 4. Upload abort on dialog cancel
**Rationale:** If the user dismisses the tag dialog, it means they don't want to proceed with this upload. The batch continues to the next file if any, rather than halting entirely.

## Risks / Trade-offs

- **[Low] Extra click per upload**: When the setting is enabled, every upload requires one extra interaction. This is opt-in and the setting default is off. → Mitigation: toggle is clearly labeled in settings.
- **[Low] Dialog fetch latency**: `TagSelectionDialog` fetches tags from the API on open, adding a round-trip delay before the user can interact. Already present today in the existing tag configuration flow. → Mitigation: acceptable; no additional impact.
