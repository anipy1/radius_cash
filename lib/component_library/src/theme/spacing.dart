/// The Contra kit's spacing scale: 2, 4, 8, 12, 16, 24, 32.
///
/// Every padding, gap and radius in the app is one of these. A literal 16 in
/// a widget is a mistake, even when it happens to equal one.
abstract class Spacing {
  static const double xxSmall = 2;
  static const double xSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double mediumLarge = 16;
  static const double large = 24;
  static const double xLarge = 32;
  static const double xxLarge = 48;
  static const double xxxLarge = 64;
}
