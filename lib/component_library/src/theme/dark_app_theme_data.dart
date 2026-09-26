import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_theme_data.dart';
import 'tone.dart';

/// The kit is drawn for light. Dark keeps its shapes and swaps the ink: light
/// outlines on the kit's black, with the same accent colours.
class DarkAppThemeData extends AppThemeData {
  @override
  ThemeData get materialThemeData => ThemeData(
    brightness: Brightness.dark,
    fontFamily: AppThemeData.fontFamily,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.dark(
      primary: accentColor,
      onPrimary: onAccentColor,
      surface: surfaceColor,
      onSurface: onSurfaceColor,
      error: dangerColor,
    ),
    useMaterial3: true,
  );

  @override
  Color get backgroundColor => AppPalette.black;
  @override
  Color get surfaceColor => AppPalette.black800;
  @override
  Color get onSurfaceColor => AppPalette.white;
  @override
  Color get mutedColor => AppPalette.black300;
  @override
  Color get borderColor => AppPalette.white;
  @override
  Color get dividerColor => AppPalette.black700;
  @override
  Color get accentColor => AppPalette.blue800;
  @override
  Color get onAccentColor => AppPalette.black;
  @override
  Color get successColor => AppPalette.green800;
  @override
  Color get warningColor => AppPalette.yellow800;
  @override
  Color get dangerColor => AppPalette.red800;
  @override
  Color get highlightColor => AppPalette.black800;

  @override
  Color tintOf(Tone tone) => switch (tone) {
    Tone.neutral => AppPalette.black800,
    Tone.accent => AppPalette.blue,
    Tone.success => AppPalette.green,
    Tone.warning => AppPalette.yellow,
    Tone.danger => AppPalette.red,
    Tone.highlight => AppPalette.pink,
  };
}
