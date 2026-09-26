---
name: localization
description: Internationalization with Flutter gen-l10n — ARB files, key naming, string ownership, and localized access in widgets. Use whenever adding or changing ANY user-visible text, labels, tooltips, error messages, or supporting a new language.
---

# Localization (l10n)

Source: *Real-World Flutter by Tutorials* ch. 9 (Internationalizing & Localizing).

## The absolute rule

**No hardcoded user-visible strings. Ever.** Every label, title, button text, error
message, tooltip, and semantics label goes through l10n — even if the app currently
ships one language. Chapter 9 is emphatic that internationalization belongs in a
project from day one — retrofitting is far more expensive.

## Setup (single package)

`l10n.yaml` at the project root:

```yaml
arb-dir: lib/l10n
template-arb-file: messages_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false   # generated code is committed under lib/l10n/
nullable-getter: false     # AppLocalizations.of(context) is non-null
```

- ARB files: `lib/l10n/messages_en.arb`, `messages_pt.arb`, … (template first).
- Run `flutter gen-l10n` after editing ARB files; commit the generated files.
- Register in `MaterialApp`: `localizationsDelegates:
  [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates]` (or
  `AppLocalizations.localizationsDelegates`), plus `supportedLocales`.

> **Kit deviation**: the book gives each package its own l10n (one `XLocalizations`
> class per feature). In this single-package layout there is one `lib/l10n/`;
> string *ownership* is preserved through key prefixes instead. Do not create
> per-feature l10n setups.

## Key naming — the ownership rule

- **Name strings after the place they appear** (ch. 9 Key Points): the same English
  text can translate differently in different contexts, so never share one key
  across screens because the text happens to match today.
- Prefix every key with its feature (camelCase):
  `signInEmailTextFieldLabel`, `quoteListRefreshErrorMessage`,
  `profileMenuSignOutButtonLabel`. Component-library widget strings get the widget
  prefix: `favoriteIconButtonTooltip`, `exceptionIndicatorGenericTitle`.
- App-shell strings (tab labels) use an `app`/shell prefix.

ARB entry shape (placeholders + plurals via ICU syntax):

```json
{
  "quoteListItemCountMessage": "{count, plural, =1{1 quote found} other{{count} quotes found}}",
  "@quoteListItemCountMessage": {
    "placeholders": { "count": { "type": "int" } }
  }
}
```

## Usage in widgets

First line of every View's `build`:

```dart
final l10n = AppLocalizations.of(context);
// ...
Text(l10n.quoteListEmptyStateTitle)
```

Never pass translated strings down through constructors when the child can resolve
them itself — except component-library-style widgets receiving display *data*
(a quote's body is data, a button's label may be a parameter fed from the caller's
l10n).

## Scope of internationalization

It's not only text: units, date/number formats, and images with embedded text are
all translatable resources (ch. 9 Key Points). Use `intl` formatters
(`DateFormat`, `NumberFormat`) with the active locale rather than hand-rolled
formatting.

## Adding a language checklist

1. Copy `messages_en.arb` → `messages_<code>.arb`, translate values (keys stay
   identical).
2. Add the locale to `supportedLocales`.
3. `flutter gen-l10n`, commit generated files.
4. Widget tests keep pumping with a fixed `locale: Locale('en')` (see `testing`
   skill).
