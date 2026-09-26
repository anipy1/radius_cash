import 'package:flutter/material.dart';

import 'app_theme_data.dart';

/// Hands the app's theme down the tree. Material decides light or dark; this
/// picks the matching [AppThemeData].
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
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? inherited!.darkTheme
        : inherited!.lightTheme;
  }
}
