import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_theme_data.dart';
import 'tone.dart';

class LightAppThemeData extends AppThemeData {
  @override
  ThemeData get materialThemeData => ThemeData(
    brightness: Brightness.light,
    fontFamily: AppThemeData.fontFamily,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.light(
      primary: accentColor,
      onPrimary: onAccentColor,
      surface: surfaceColor,
      onSurface: onSurfaceColor,
      error: dangerColor,
    ),
    useMaterial3: true,
  );

  @override
  Color get backgroundColor => AppPalette.white;
  @override
  Color get surfaceColor => AppPalette.white;
  @override
  Color get onSurfaceColor => AppPalette.black;
  @override
  Color get mutedColor => AppPalette.black800;
  @override
  Color get borderColor => AppPalette.black;
  @override
  Color get dividerColor => AppPalette.black300;
  @override
  Color get accentColor => AppPalette.blue;
  @override
  Color get onAccentColor => AppPalette.white;
  @override
  Color get successColor => AppPalette.green;
  @override
  Color get warningColor => AppPalette.yellow;
  @override
  Color get dangerColor => AppPalette.red;
  @override
  Color get highlightColor => AppPalette.yellow100;

  @override
  Color tintOf(Tone tone) => switch (tone) {
    Tone.neutral => AppPalette.black100,
    Tone.accent => AppPalette.blue100,
    Tone.success => AppPalette.green100,
    Tone.warning => AppPalette.yellow100,
    Tone.danger => AppPalette.red100,
    Tone.highlight => AppPalette.pink200,
  };
}
