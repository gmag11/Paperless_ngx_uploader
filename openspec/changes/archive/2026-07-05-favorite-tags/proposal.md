## Why

Users with many tags lose time scrolling through long lists to find their most-used tags. Marking frequently-used tags as favorites and sorting them near the top makes tag selection faster and reduces friction in the upload workflow.

## What Changes

- Add a `favoriteTagIds` field (`List<int>`) to `ServerConfig`, persisted alongside existing server settings.
- Add a star icon button to each tag row in `TagSelectionDialog`. Tapping the star toggles favorite status for that tag.
- Sort the tag list in three tiers: selected tags first, favorite tags second, and remaining tags third.
- The sort order is applied when the tag list is loaded/refreshed — not on each toggle — so users can undo accidental favorites before the sort takes effect.
- Favorite state persists across app restarts and is server-specific.
- Favorite tag IDs that no longer exist on the server (deleted tags) are silently ignored — only tags returned by the API are displayed.

## Capabilities

### New Capabilities
- `favorite-tags`: Allow users to mark tags as favorites via a star icon and sort them above non-favorite, non-selected tags in the tag selection dialog.

### Modified Capabilities
<!-- None — this is a new capability built on top of existing tag infrastructure -->

## Impact

- **Model**: `ServerConfig` — new `favoriteTagIds` field (`List<int>`, defaults to `[]`), `toJson`/`fromJson`/`copyWith` updated.
- **UI**: `TagSelectionDialog` — star icon per tag row, sorting logic (selected → favorites → rest).
- **Storage**: `ServerManager` / secure storage — favorites are persisted inside `ServerConfig` JSON; no new storage keys needed.
- **Localization**: New strings for star icon tooltip (EN/ES).
