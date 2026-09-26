---
name: design-system
description: Component library, custom theme via InheritedWidget, Spacing/FontSize design tokens, dark mode, and widget catalog. Use when creating or styling any widget, choosing colors/spacing/typography, implementing dark mode, or adding reusable UI components.
---

# Design System (component_library + theming)

Source: *Real-World Flutter by Tutorials* ch. 10 (Dynamic Theming & Dark Mode) &
ch. 11 (Creating Your Own Widget Catalog).

## What lives in `lib/component_library/`

- Reusable widgets used by **two or more** features: buttons, cards, indicators,
  snackbars, search bars, icons.
- The theme: `AppTheme` InheritedWidget, abstract `AppThemeData`,
  `LightAppThemeData`/`DarkAppThemeData`.
- Design tokens: `Spacing`, `FontSize`.
- Shared assets (fonts, SVGs).

**Promotion rule**: a widget used by only one feature stays in that feature's
`src/`. Move it to the component library only when a second feature needs it.

## Component design rules

- Library widgets are **app-agnostic**: primitives in (`String`, `bool`, `int`),
  callbacks out (`VoidCallback onTap`). They never accept domain models, never
  import repositories, and never contain business logic.
  (`QuoteCard(statement:, author:, isFavorite:, onFavorite:)` — not
  `QuoteCard(quote: Quote)`.)
- Accessibility strings inside library widgets (tooltips, semantics labels) are
  localized within the app's l10n like all other strings.
- Provide named variants instead of boolean soup:
  `ExpandedElevatedButton.inProgress(label:)`.

## Design tokens — no magic numbers

```dart
abstract class Spacing {
  static const double xSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double mediumLarge = 16;
  static const double large = 20;
  static const double xLarge = 24;
  static const double xxLarge = 48;
  static const double xxxLarge = 64;
}

abstract class FontSize {
  static const double small = 11;
  static const double medium = 14;
  static const double mediumLarge = 18;
  static const double large = 22;
  static const double xLarge = 64;
}
```

Every padding, gap, radius, and font size references a token (or a theme getter).
A literal `EdgeInsets.all(16)` in feature code is a violation — use
`EdgeInsets.all(Spacing.mediumLarge)`.

## Theme architecture — custom InheritedWidget

Material's `ThemeData` can't hold arbitrary app tokens, so wrap it in a custom
theme built on `InheritedWidget` — the approach ch. 10 lands on for maximum
flexibility:

```dart
abstract class AppThemeData {
  ThemeData get materialThemeData; // fed to MaterialApp.theme/darkTheme

  // app-specific tokens — every getter overridden by both subclasses
  double get screenMargin => Spacing.mediumLarge;
  Color get roundedChoiceChipBackgroundColor;
  Color get quoteSvgColor;
  TextStyle get quoteTextStyle;
}

class LightAppThemeData extends AppThemeData { /* light values */ }
class DarkAppThemeData extends AppThemeData { /* dark values */ }

class AppTheme extends InheritedWidget {
  const AppTheme({
    required this.lightTheme,
    required this.darkTheme,
    required super.child,
    super.key,
  });

  final AppThemeData lightTheme;
  final AppThemeData darkTheme;

  @override
  bool updateShouldNotify(AppTheme oldWidget) =>
      oldWidget.lightTheme != lightTheme || oldWidget.darkTheme != darkTheme;

  static AppThemeData of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(inherited != null, 'No AppTheme found in context');
    final brightness = Theme.of(context).brightness; // Material decides light/dark
    return brightness == Brightness.dark ? inherited!.darkTheme : inherited!.lightTheme;
  }
}
```

Usage in every View: `final theme = AppTheme.of(context);` as one of the first
lines of `build`.

## Dark mode — the reactive preference loop (ch. 10 Key Points)

Support three modes: light, dark, system. The preference is app state owned by the
user repository:

1. `DarkModePreference` enum (`alwaysLight`, `alwaysDark`, `useSystemSettings`) in
   `domain_models/`, persisted via local storage (CM enum + mapper).
2. Repository exposes `Stream<DarkModePreference>` backed by a `BehaviorSubject`.
3. Root widget: `StreamBuilder<DarkModePreference>` → `AppTheme(lightTheme:,
   darkTheme:, child: MaterialApp.router(theme:, darkTheme:, themeMode:
   preference.toThemeMode(), ...))`.
4. The settings feature calls
   `userRepository.upsertDarkModePreference(...)` — the whole app re-themes
   reactively.

## Widget catalog (ch. 11)

Chapter 11 describes a storybook as the component library made visible: it lets
designers and developers browse every shared widget in both themes without running
the app. Keep one as a separate entrypoint, e.g. `catalog/main.dart` or
`lib/main_catalog.dart`, using `widgetbook` (or `storybook_flutter`):

- One story per component-library widget, grouped by section (Buttons,
  Indicators…).
- Wire the same `AppTheme` light/dark wrapping as the real `main.dart` so stories
  render in both themes.
- Configure knobs for the attributes a user would want to tweak (labels, flags,
  counts) (ch. 11 Key Points).
- Add a story whenever you add a component-library widget.

## Why (from the book)

Chapter 10 picks custom InheritedWidget theming because it is the most adjustable
of the available options (while noting simpler apps can use simpler approaches);
chapter 11 keeps the component library discoverable and testable in isolation
through the catalog. Tokens + theme getters are what make dark mode a data change
instead of a refactor.
