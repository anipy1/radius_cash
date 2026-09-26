import 'dart:convert';

import 'package:formz/formz.dart';

enum BountyTitleValidationError { empty, tooLong }

/// What the bounty is, in one line. Bounded in UTF-8 bytes because that is
/// what the wire record carries.
class BountyTitle extends FormzInput<String, BountyTitleValidationError> {
  const BountyTitle.unvalidated([super.value = '']) : super.pure();

  const BountyTitle.validated(super.value) : super.dirty();

  static const maxBytes = 100;

  @override
  BountyTitleValidationError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return BountyTitleValidationError.empty;
    if (utf8.encode(trimmed).length > maxBytes) {
      return BountyTitleValidationError.tooLong;
    }
    return null;
  }
}
