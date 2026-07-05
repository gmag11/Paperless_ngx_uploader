## Context

The `TagSelectionDialog` currently displays tags as a flat, alphabetically sorted list fetched from the Paperless-ngx API. Users with dozens of tags must scroll extensively to find their frequently-used tags. The `ServerConfig` model already stores per-server configuration (default tags, auth, etc.) and is persisted as JSON via secure storage. Favorites are a natural extension of this per-server configuration.

## Goals / Non-Goals

**Goals:**
- Store favorite tag IDs per server in `ServerConfig`
- Show a star icon on each tag row in the tag dialog to toggle favorite status
- Sort tags in three tiers: selected → favorites → rest
- Defer sort until reload so users can undo accidental toggles
- Persist favorites via existing `ServerConfig` JSON storage

**Non-Goals:**
- Syncing favorites to the Paperless-ngx server (local-only)
- Favorite tags affecting upload behavior (only sorting)
- Cross-server favorite sharing
- Drag-to-reorder or custom tag ordering

## Decisions

### Decision 1: Store favorites as `List<int>` on `ServerConfig`
**Rationale:** Favorites are per-server, like `defaultTagIds`. A flat list of tag IDs is the simplest representation and integrates seamlessly with the existing `toJson`/`fromJson` serialization. No new storage keys or migration needed.

**Alternatives considered:**
- Separate secure storage key: Adds complexity for no benefit; favorites are server config, not credentials.
- `Set<int>`: Not native to JSON serialization; requires manual conversion.

### Decision 2: Sort deferred until reload, not on each toggle
**Rationale:** Immediate re-sorting on every star tap would move the tag while the user is looking at it, creating a jarring UX. Deferring sort until reload gives the user a chance to correct mistakes before the tag jumps position.

**Alternatives considered:**
- Immediate re-sort with animation: More complex, and the star feedback itself is enough; the repositioning adds visual noise.

### Decision 3: Three-tier sort: selected, favorite, alphabetical within tier
**Rationale:** Selected tags are the most actionable (about to be saved), favorites are frequently-used, and alphabetical within tiers keeps the list scannable. This mirrors how many apps (Gmail labels, Finder tags) handle prioritized lists.

**Alternatives considered:**
- Two-tier (favorites + rest, ignoring selected): Selected tags need to stay visible so users know what they've chosen. Losing them in the list is confusing.
- Most-recently-used order: Requires per-tag timestamp tracking, over-engineering for this use case.

### Decision 4: Star icon inline in the tag row, aligned right
**Rationale:** Placing the star on the right side of each `ListTile` keeps it visually consistent with other interactive elements (the checkbox is on the left). It does not interfere with the existing checkbox + color dot + name layout.

**Alternatives considered:**
- Long-press to favorite: Less discoverable; a visible star is immediate and standard.
- Swipe action: Over-engineering for a single action; a star icon is simpler.

## Risks / Trade-offs

- **[Risk] Accidentally marking wrong tags as favorite** → Mitigation: Sort is deferred until reload; user can immediately tap again to undo before the list reorders.
- **[Risk] Favorite list grows large and matches the full tag list** → Mitigation: When all tags are favorites, the three-tier sort collapses to selected → favorites, which is essentially the same list as before minus unselected non-favorites. No perf hit; `List<int>` lookup is O(1) with a Set.
- **[Trade-off] Favorites stored locally, not on server** → Acceptable: favorites are a UI preference, not data. If user reinstalls or switches device, they re-mark favorites once.
