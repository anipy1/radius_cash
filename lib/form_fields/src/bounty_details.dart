import 'dart:convert';

import 'package:formz/formz.dart';

enum BountyDetailsValidationError { tooLong }

/// Where, when, anything else. Optional.
class BountyDetails extends FormzInput<String, BountyDetailsValidationError> {
  const BountyDetails.unvalidated([super.value = '']) : super.pure();

  const BountyDetails.validated(super.value) : super.dirty();

  static const maxBytes = 500;

  @override
  BountyDetailsValidationError? validator(String value) =>
      utf8.encode(value.trim()).length > maxBytes
      ? BountyDetailsValidationError.tooLong
      : null;
}
