import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'font_size.dart';
import 'spacing.dart';
import 'tone.dart';

/// Everything a widget may ask the theme for.
///
/// Semantic, not raw: a widget asks for the surface colour, not for white, so
/// the dark theme can answer differently. Both subclasses override every
/// abstract getter; the concrete ones are shared between them because the
/// Contra kit's type and shape do not change with brightness.
abstract class AppThemeData {
  /// Fed to MaterialApp so Material widgets we have not wrapped look right.
  ThemeData get materialThemeData;

  static const fontFamily = 'Montserrat';

  double get screenMargin => Spacing.mediumLarge;
  double get borderWidth => AppPalette.borderWidth;
  double get cornerRadius => Spacing.mediumLarge;
  double get smallCornerRadius => Spacing.medium;

  Color get backgroundColor;
  Color get surfaceColor;
  Color get onSurfaceColor;
  Color get mutedColor;
  Color get borderColor;
  Color get dividerColor;
  Color get accentColor;
  Color get onAccentColor;
  Color get successColor;
  Color get warningColor;
  Color get dangerColor;
  Color get highlightColor;

  /// The strong colour of a family, for fills that carry meaning.
  Color colorOf(Tone tone) => switch (tone) {
    Tone.neutral => surfaceColor,
    Tone.accent => accentColor,
    Tone.success => successColor,
    Tone.warning => warningColor,
    Tone.danger => dangerColor,
    Tone.highlight => highlightColor,
  };

  /// The pale member of the same family, for backgrounds behind text.
  Color tintOf(Tone tone);

  /// Text that reads on [colorOf].
  Color onColorOf(Tone tone) => switch (tone) {
    Tone.accent => onAccentColor,
    Tone.neutral || Tone.highlight => onSurfaceColor,
    Tone.success || Tone.warning || Tone.danger => AppPalette.black,
  };

  BoxShadow get hardShadow =>
      BoxShadow(color: borderColor, offset: AppPalette.shadowOffset400);

  BoxShadow get smallHardShadow =>
      BoxShadow(color: borderColor, offset: AppPalette.shadowOffset200);

  BoxBorder get border => Border.all(color: borderColor, width: borderWidth);

  /// The kit's one shape: a filled box with the border, rounded, and when
  /// [raised] the hard shadow underneath. Every card, button and field is
  /// this with a different colour.
  BoxDecoration boxDecoration({
    required Color color,
    bool raised = false,
    double? radius,
  }) => BoxDecoration(
    color: color,
    border: border,
    borderRadius: BorderRadius.circular(radius ?? cornerRadius),
    boxShadow: raised ? [hardShadow] : const [],
  );

  TextStyle get displayTextStyle => _style(FontSize.display, 54, _extraBold);
  TextStyle get headingTextStyle => _style(FontSize.xxxLarge, 40, _extraBold);
  TextStyle get titleTextStyle => _style(FontSize.xxLarge, 32, _bold);
  TextStyle get subtitleTextStyle => _style(FontSize.large, 28, _bold);
  TextStyle get bodyTextStyle => _style(FontSize.mediumLarge, 24, _medium);
  TextStyle get bodyStrongTextStyle => _style(FontSize.mediumLarge, 24, _bold);
  TextStyle get smallTextStyle => _style(FontSize.medium, 20, _medium);
  TextStyle get captionTextStyle => _style(FontSize.small, 18, _medium);
  TextStyle get labelTextStyle => _style(FontSize.xSmall, 16, _bold);
  TextStyle get buttonTextStyle => _style(FontSize.large, 28, _bold);

  static const _extraBold = FontWeight.w800;
  static const _bold = FontWeight.w700;
  static const _medium = FontWeight.w500;

  TextStyle _style(double size, double lineHeight, FontWeight weight) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: onSurfaceColor,
      );
}
