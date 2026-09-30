# Tasks

## 1. Provider updates preserve settings

- [x] 1.1 Replace the fresh `ServerConfig(...)` in
  `AppConfigProvider.setAllowSelfSignedCertificates` with `server.copyWith(...)`;
  verify the method still updates the field.
- [x] 1.2 Make `AppConfigProvider.saveConfiguration` preserve the fields it
  previously dropped (custom headers, default tags, ask-tags, favorites) while
  still clearing the auth field it replaces, since `copyWith` cannot clear
  nullables; verify saving credentials still works.

## 2. Dialog save preserves unmanaged fields

- [x] 2.1 Add the pure `applyServerFormUpdate(existing, {...form values...})`
  helper that preserves `askTagsBeforeUpload` and `favoriteTagIds` and clears
  custom headers when the form has none; verify a unit test for both behaviors.
- [x] 2.2 Use the helper in `ConfigDialog._saveAndTestServer` for both the draft
  test configuration and the saved server; verify `flutter analyze` is clean.

## 3. Regression tests

- [x] 3.1 Add a test asserting `ServerConfig.copyWith` preserves unrelated fields;
  verify it passes.
- [x] 3.2 Add tests for the helper: it keeps the ask-tags option and favorites,
  and clears custom headers when passed an empty map; verify they pass.
- [x] 3.3 Run `flutter test` and `flutter analyze` clean.
- [x] 3.4 Add tests exercising the real provider methods
  (`setAllowSelfSignedCertificates`, `saveConfiguration`) through an in-memory
  `ServerManager`; verify they preserve unrelated fields and still clear the
  replaced auth field.

## 4. Manual verification

- [x] 4.1 On a device: toggle self-signed and confirm custom headers, default
  tags and the ask-tags option survive; edit a server via the form and confirm
  the ask-tags option is unchanged.
