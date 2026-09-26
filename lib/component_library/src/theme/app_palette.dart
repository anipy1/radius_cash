import 'package:flutter/painting.dart';

/// The Contra wireframe kit palette, named as the kit names its styles.
///
/// Raw colours. Widgets do not use these directly; they go through the
/// semantic getters on [AppThemeData], so a dark theme is a data change.
abstract class AppPalette {
  static const black = Color(0xFF18191F);
  static const black800 = Color(0xFF474A57);
  static const black700 = Color(0xFF969BAB);
  static const black300 = Color(0xFFD9DBE1);
  static const black200 = Color(0xFFEEEFF4);
  static const black100 = Color(0xFFF4F5F7);
  static const white = Color(0xFFFFFFFF);

  static const blue = Color(0xFF1947E5);
  static const blue800 = Color(0xFF8094FF);
  static const blue100 = Color(0xFFE9E7FC);

  static const pink = Color(0xFFFF89BB);
  static const pink800 = Color(0xFFFFC7DE);
  static const pink200 = Color(0xFFFFF3F8);

  static const yellow = Color(0xFFFFBD12);
  static const yellow800 = Color(0xFFFFD465);
  static const yellow100 = Color(0xFFFFF4CC);

  static const green = Color(0xFF00C6AE);
  static const green800 = Color(0xFF61E4C5);
  static const green100 = Color(0xFFD6FCF7);

  static const red = Color(0xFFF95A2C);
  static const red800 = Color(0xFFFF9692);
  static const red100 = Color(0xFFFFE8E8);

  /// Everything in the kit has this border.
  static const double borderWidth = 2;

  /// The kit's shadows have no blur: a solid offset copy of the outline.
  static const Offset shadowOffset200 = Offset(0, 2);
  static const Offset shadowOffset400 = Offset(0, 4);
  static const Offset shadowOffset600 = Offset(0, 6);
}
