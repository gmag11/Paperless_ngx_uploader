# Spec Delta

## Purpose

Guarantees that changing one field of a server configuration leaves every other
field untouched, so settings never disappear because of an unrelated edit.

## ADDED Requirements

### Requirement: Partial updates preserve unrelated settings

When the app updates a single field of a server configuration, it SHALL preserve
every field it does not explicitly change, including custom headers, default tag
IDs, the ask-tags-before-upload option and favorite tag IDs.

#### Scenario: Changing the self-signed option keeps other settings

- **WHEN** the self-signed certificate option of a server is changed
- **THEN** the server's custom headers, default tags, ask-tags option and
  favorite tags are unchanged

#### Scenario: Saving credentials keeps other settings

- **WHEN** a server's URL, username, password or API token is updated
- **THEN** the server's custom headers, default tags, ask-tags option and
  favorite tags are unchanged

#### Scenario: Editing the server form keeps the ask-tags option

- **WHEN** a user edits and saves an existing server through the configuration
  form, which does not expose the ask-tags option
- **THEN** the server's ask-tags-before-upload option keeps its previous value

### Requirement: Explicit changes and clears still apply

The preservation rule SHALL NOT prevent a field from being changed or cleared
when the user edits it, so removing all custom headers or changing the tag list
still takes effect.

#### Scenario: Removing custom headers takes effect

- **WHEN** a user removes every custom header for a server and saves
- **THEN** the server ends up with no custom headers

#### Scenario: Changing the default tags takes effect

- **WHEN** a user changes the default tags of a server
- **THEN** the new tag list is stored and unrelated settings are preserved
