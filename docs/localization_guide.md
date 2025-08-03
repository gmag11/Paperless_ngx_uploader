# Localization Guide

This guide explains how to add new languages and translations to the app using Flutter's localization system.

---

## 1. Creating New ARB Files

1. Navigate to [`lib/l10n`](lib/l10n).
2. Copy the existing `intl_en.arb` file and rename it for your target language, e.g. `intl_es.arb` for Spanish.
3. Use [ISO 639-1 language codes](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) in filenames.

**Example:**

- `intl_en.arb` (English)
- `intl_es.arb` (Spanish)
- `intl_fr.arb` (French)

---

## 2. Adding Translations and Handling Placeholders

- Each ARB file contains key-value pairs for strings.
- For each key, provide the translated value.

**Example:**

```json
{
  "appTitle": "Paperless Uploader",
  "welcomeMessage": "Welcome, {username}!"
}
```

**Placeholders:**

- Use curly braces `{}` for variables.
- Ensure all ARB files have matching keys and placeholders.
- Add a `@` metadata entry for each placeholder:

```json
{
  "welcomeMessage": "Bienvenido, {username}!",
  "@welcomeMessage": {
    "description": "Welcome message with username",
    "placeholders": {
      "username": {}
    }
  }
}
```

---

## 3. Regenerating Localization Classes

After editing ARB files:

1. Run the following command in your project root:

   ```sh
   flutter gen-l10n
   ```

2. This generates localization classes in [`lib/l10n/gen`](lib/l10n/gen).

---

## 4. Updating Supported Locales in MaterialApp

To support the new language:

1. Open [`lib/main.dart`](lib/main.dart).
2. Update the `supportedLocales` parameter in `MaterialApp`:

```dart
supportedLocales: const [
  Locale('en'),
  Locale('es'), // Add new locales here
  Locale('fr'),
],
```

3. Ensure the locale code matches your ARB filename.

---

## 5. Troubleshooting Tips

- **Missing translations:** If a key is missing in an ARB file, the app falls back to the default language.
- **Placeholder errors:** Ensure placeholders are present and match across all ARB files.
- **Regeneration issues:** If changes do not appear, run `flutter clean` then `flutter gen-l10n`.
- **Locale not switching:** Confirm the locale is listed in `supportedLocales` and the ARB file exists.
- **Format errors:** Validate ARB files are proper JSON.

---

For more details, see [Flutter localization documentation](https://docs.flutter.dev/accessibility-and-localization/internationalization).
