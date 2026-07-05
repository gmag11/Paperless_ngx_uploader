## ADDED Requirements

### Requirement: Server-specific favorite tag storage
The system SHALL store a list of favorite tag IDs per server in the `ServerConfig` model, defaulting to an empty list.

#### Scenario: New server has no favorites
- **WHEN** a new server is created
- **THEN** `favoriteTagIds` is an empty list and no stars are filled in the tag dialog

#### Scenario: Favorite tag IDs survive app restart
- **WHEN** a user marks tags as favorites and restarts the app
- **THEN** the same tags remain marked as favorites for that server

#### Scenario: Favorites are server-specific
- **WHEN** a user switches between two servers that have different favorite tags
- **THEN** each server shows only its own favorites, not the other server's

### Requirement: Star icon toggle in tag selection dialog
Each tag row in `TagSelectionDialog` SHALL display a star icon button on the right side. Tapping the star SHALL toggle the tag's favorite status.

#### Scenario: Mark a tag as favorite
- **WHEN** a user taps the empty star icon on a non-favorite tag
- **THEN** the star becomes solid/filled, the tag ID is added to `favoriteTagIds`, and the change is persisted to the server config

#### Scenario: Unmark a tag as favorite
- **WHEN** a user taps the filled star icon on a favorite tag
- **THEN** the star becomes empty/outlined, the tag ID is removed from `favoriteTagIds`, and the change is persisted to the server config

#### Scenario: Favorite toggle does not move the tag immediately
- **WHEN** a user toggles a tag's favorite status (star)
- **THEN** the tag SHALL NOT move position in the list until the tag list is reloaded or the dialog is reopened

### Requirement: Tag list three-tier sorting
When the tag list is loaded or refreshed, the system SHALL sort tags in three tiers: selected tags first, favorite tags second, and remaining tags last.

#### Scenario: Sorting on initial load
- **WHEN** the tag selection dialog opens and loads tags from the server
- **THEN** tags appear in order: selected → favorite → remaining, with alphabetical order within each tier

#### Scenario: Sorting on search filter
- **WHEN** a user types a search query that filters the tag list
- **THEN** the filtered results SHALL maintain the three-tier sort order (selected → favorite → remaining)

#### Scenario: Empty favorites has no effect
- **WHEN** a server has no favorite tags configured (empty list)
- **THEN** the tag list shows selected tags first and remaining tags second, with no gap for favorites

#### Scenario: Favorite tag deleted from server
- **WHEN** a tag is marked as favorite locally but has been deleted from the Paperless-ngx server and no longer appears in the API response
- **THEN** the tag SHALL NOT appear in the list and the app SHALL NOT produce any error — the orphaned favorite ID is silently ignored
