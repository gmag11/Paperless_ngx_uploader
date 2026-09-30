# Design

## Context

See `proposal.md` for motivation. Current state relevant to the approach:

- `AppConfigProvider.setAllowSelfSignedCertificates` and
  `AppConfigProvider.saveConfiguration` build a fresh `ServerConfig(...)` passing
  only id, name, URL, auth, username/token and the one field being changed, so
  `customHeaders`, `defaultTagIds`, `askTagsBeforeUpload` and `favoriteTagIds`
  revert to defaults.
- `ConfigDialog._saveAndTestServer` builds a fresh `ServerConfig(...)` on save
  carrying `defaultTagIds`, `allowSelfSignedCertificates` and `customHeaders`, but
  not `askTagsBeforeUpload` or `favoriteTagIds`, so saving from the form resets
  the ask-tags option.
- `ServerConfig.copyWith` exists but, like the generated template, treats a
  `null` argument as "keep the existing value", so it cannot clear a nullable
  field such as `customHeaders`.
- `home_screen` already uses `copyWith` for its own updates and is not affected.

## Goals / Non-Goals

**Goals:**
- One clear rule: a partial update changes only what it names.
- A testable path for the dialog's merge that can still clear custom headers.
- Regression tests that do not require platform plugins.

**Non-Goals:**
- Recovering settings already lost by previous versions.
- Changing the model, the storage schema or the form fields.
- Reworking unrelated construction sites (legacy migration intentionally creates
  new servers).

## Decisions

1. **Provider partial updates use `ServerConfig.copyWith`.** Both
   `setAllowSelfSignedCertificates` and `saveConfiguration` change a single
   concern, so `server.copyWith(...)` is the correct primitive.
   - *Why*: it preserves every field by construction and makes the intent
     explicit.
   - *Discarded alternative*: listing all fields by hand in every method — the
     current approach, which is exactly what dropped data.

2. **The dialog's save uses a small pure helper instead of a fresh
   `ServerConfig(...)`.** A pure function merges the form's values into the
   existing server and preserves the fields the form does not manage
   (`askTagsBeforeUpload`, `favoriteTagIds`), while still allowing custom headers
   to be cleared.
   - *Shape*: something like
     `ServerConfig applyServerFormUpdate(ServerConfig? existing, {...form values...})`,
     where passing an empty/absent custom-header map clears the headers and the
     rest is taken from the form.
   - *Why*: the dialog is a full-form editor, so it legitimately overrides the
     fields it shows; a pure helper makes the preservation rule unit-testable
     without a widget test or platform plugins, and sidesteps the `copyWith`
     null-clearing limitation.
   - *Discarded alternatives*: extend `copyWith` with a sentinel/`clearX` flag for
     every nullable field (noise in the model for one caller); keep the inline
     `ServerConfig(...)` and just add the two missing fields (works, but not
     testable in isolation and easy to regress again).

3. **Do not change `ServerConfig.copyWith` semantics.** Its "null keeps the
   existing value" behavior is relied on elsewhere and is a common Dart idiom;
   the clearing need is handled explicitly in the helper.
   - *Why*: the smallest change that fixes the bug without touching shared
     semantics.

4. **Regression tests are pure Dart.** They cover (a) `copyWith` preserving
   unrelated fields, and (b) the helper preserving unmanaged fields and clearing
   custom headers when asked.
   - *Why*: no `ServerManager`, secure storage or widget harness needed; runs in
     the existing `flutter test` suite.

## Risks / Trade-offs

- [Settings already lost by earlier versions are not restored] → Accept; the
  change prevents future loss. Documented as a non-goal.
- [A future field added to `ServerConfig` might be forgotten in the helper] →
  The helper is the single merge point for the form, and the preservation test
  can assert a representative set; adding a field is a visible change to the
  helper.
- [The dialog still rebuilds other fields from the form] → Intended: the form is
  the source of truth for the fields it displays; only unmanaged fields are
  carried over.

## Migration Plan

Additive bug fix shipped in a normal app update; no stored-data migration.
Rollback reverts the commit and restores the previous (lossy) behavior.

## Open Questions

- Whether `applyServerFormUpdate` lives on `ServerConfig` or as a top-level
  function in a small file can be decided during implementation; it does not
  change the specs or the task breakdown.
