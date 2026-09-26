import 'package:formz/formz.dart';

enum BountyExpiryValidationError { inThePast }

/// When the bounty stops being worth showing. Validated against a clock
/// handed in, so the same value can be right now and wrong in an hour.
class BountyExpiry extends FormzInput<DateTime, BountyExpiryValidationError> {
  const BountyExpiry.unvalidated(super.value, {required this.now})
    : super.pure();

  const BountyExpiry.validated(super.value, {required this.now})
    : super.dirty();

  final DateTime now;

  /// Presets a form offers; the last one is the default.
  static const presets = [
    Duration(hours: 1),
    Duration(hours: 4),
    Duration(hours: 24),
    Duration(days: 3),
  ];

  static const defaultPreset = Duration(hours: 24);

  @override
  BountyExpiryValidationError? validator(DateTime value) =>
      value.isAfter(now) ? null : BountyExpiryValidationError.inThePast;
}
