# Proposal

## Why

Updating one server setting sometimes discards the others. `AppConfigProvider`
rebuilds a `ServerConfig` from scratch in `saveConfiguration` and
`setAllowSelfSignedCertificates`, passing only a few fields, so
`customHeaders`, `defaultTagIds`, `askTagsBeforeUpload` and `favoriteTagIds` are
reset. Separately, saving the server form in `ConfigDialog` rebuilds the
`ServerConfig` without `askTagsBeforeUpload`, so editing a server silently turns
that option off. The result is settings that disappear without the user asking,
inconsistent with the `custom-request-headers`, `ask-tags-on-upload` and
`favorite-tags` capabilities.

## What Changes

- Make every partial update of a server preserve the settings it does not
  explicitly change, using `ServerConfig.copyWith` instead of rebuilding the
  object:
  - `AppConfigProvider.setAllowSelfSignedCertificates`
  - `AppConfigProvider.saveConfiguration`
- Make `ConfigDialog._saveAndTestServer` preserve `askTagsBeforeUpload` (and
  `favoriteTagIds`) when editing an existing server, instead of dropping them on
  save.
- Add regression tests that update one setting and assert the others survive.
- No behavior change to the settings that are intentionally edited.
- No new dependencies.

## Capabilities

### New Capabilities
- `server-config-preservation`: guarantees that updating one field of a server
  configuration never discards the other fields.

### Modified Capabilities
<!-- The affected guarantees are already stated by custom-request-headers,
     ask-tags-on-upload and favorite-tags; this change makes their implementation
     stop discarding data, so their requirements do not change. -->

## Impact

- `lib/providers/app_config_provider.dart`: `setAllowSelfSignedCertificates` and
  `saveConfiguration` preserve unrelated fields.
- `lib/widgets/config_dialog.dart`: the save path preserves settings the form
  does not manage when editing an existing server.
- `lib/models/server_config.dart`: `copyWith` may need an explicit way to clear a
  field (e.g. custom headers) without losing the "keep existing" behavior.
- `test/`: regression tests for preservation.
- No stored-data migration: the bug is fixed going forward; settings already
  lost cannot be recovered automatically.

## Non-goals

- Recovering settings already lost by earlier versions.
- Redesigning how server configuration is stored or modeled.
- Changing the `ConfigDialog` form fields or the settings UI.
- The transport centralization and per-server TLS policy of
  `centralize-http-client` (this change is independent of it, though it fixes the
  provider method that the dialog used to call).
