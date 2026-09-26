import 'package:formz/formz.dart';

enum EuroAmountValidationError { empty, invalid, notPositive, tooLarge }

/// An amount typed by a person: "25", "12.50", "7,5". Held as the typed text
/// so the field can echo it back; [cents] is what the app uses.
class EuroAmount extends FormzInput<String, EuroAmountValidationError> {
  const EuroAmount.unvalidated([super.value = '']) : super.pure();

  const EuroAmount.validated(super.value) : super.dirty();

  /// Enough for any bounty anyone will post at a hackathon, and well inside
  /// the wire's 32 bits.
  static const maxCents = 100000000; // 1,000,000.00 EUR

  static final _pattern = RegExp(r'^\d{1,7}([.,]\d{1,2})?$');

  /// Null unless the value parses.
  int? get cents => parseCents(value);

  static int? parseCents(String raw) {
    final text = raw.trim();
    if (!_pattern.hasMatch(text)) return null;
    final parts = text.replaceAll(',', '.').split('.');
    final whole = int.parse(parts[0]);
    final fraction = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));
    return whole * 100 + fraction;
  }

  @override
  EuroAmountValidationError? validator(String value) {
    if (value.trim().isEmpty) return EuroAmountValidationError.empty;
    final parsed = parseCents(value);
    if (parsed == null) return EuroAmountValidationError.invalid;
    if (parsed <= 0) return EuroAmountValidationError.notPositive;
    if (parsed > maxCents) return EuroAmountValidationError.tooLarge;
    return null;
  }
}
