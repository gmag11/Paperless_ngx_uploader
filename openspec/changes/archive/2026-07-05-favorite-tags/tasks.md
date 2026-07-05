## 1. Model: Add favoriteTagIds to ServerConfig

- [x] 1.1 Add `favoriteTagIds` field (`List<int>`, defaults to `[]`) to `ServerConfig` model in `lib/models/server_config.dart`
- [x] 1.2 Update `ServerConfig.copyWith()` to include `favoriteTagIds` parameter
- [x] 1.3 Update `ServerConfig.toJson()` to serialize `favoriteTagIds`
- [x] 1.4 Update `ServerConfig.fromJson()` to deserialize `favoriteTagIds` with fallback to `[]`

## 2. UI: Star icon toggle in TagSelectionDialog

- [x] 2.1 Add `favoriteTagIds` and `onToggleFavorite` parameters to `TagSelectionDialog` in `lib/widgets/tag_selection_dialog.dart`
- [x] 2.2 Add a star `IconButton` to the trailing position of each tag's `ListTile`, showing `Icons.star` (filled) for favorites and `Icons.star_border` (outlined) for non-favorites
- [x] 2.3 Implement `_toggleFavorite(Tag tag)` method that calls `onToggleFavorite` with the toggled tag ID
- [x] 2.4 Update `_updateFilteredTags()` to apply three-tier sort: selected tags first, favorites second, remaining tags last (alphabetical within each tier)

## 3. Wiring: Favorite state in home screen and dialog invocation

- [x] 3.1 Read `favoriteTagIds` from `currentServer` and pass to `TagSelectionDialog` in `_showTagSelectionDialog()` in `lib/screens/home_screen.dart`
- [x] 3.2 Pass `favoriteTagIds` from the ask-before-upload flow when opening `TagSelectionDialog` with askTagsBeforeUpload
- [x] 3.3 Implement `onToggleFavorite` callback that updates `ServerConfig.favoriteTagIds` via `serverManager.updateServer()` and persists
- [x] 3.4 Handle the edge case where a favorited tag ID no longer exists on the server: silently ignore orphaned IDs (only tags from the API response are displayed, no error)

## 4. Localization: New UI strings

- [x] 4.1 Add English string for star tooltip (`mark_favorite` / `unmark_favorite`) in `lib/l10n/app_en.arb`
- [x] 4.2 Add Spanish string for star tooltip in `lib/l10n/app_es.arb`
- [x] 4.3 Run `flutter gen-l10n` to regenerate localization code

## 5. Testing

- [x] 5.1 Verify star toggles fill/unfill correctly and persists across dialog reopen
- [x] 5.2 Verify three-tier sort order (selected → favorites → rest) on dialog open
- [x] 5.3 Verify favorite toggle does NOT reorder the list immediately
- [x] 5.4 Verify favorites survive app restart
- [x] 5.5 Verify favorites are server-specific (different servers, different favorites)
- [x] 5.6 Verify empty favoriteTagIds (default) has no effect on sort or UI

## Review Workload Forecast

- **Estimated changed lines:** ~120-150
- **Chained PRs recommended:** No — single coherent change
- **400-line budget risk:** Low
- **Decision needed before apply:** No
