---
name: forms
description: Form validation with Formz and Cubits — field classes, validation triggers, server-side rejection feedback, and error display. Use when building or modifying any form, text input, sign-in/sign-up/profile flow, or field validation logic.
---

# Forms & Validation (Formz + Cubit)

Source: *Real-World Flutter by Tutorials* ch. 4 (Validating Forms With Cubits).

## Why validate client-side

Validating user input saves unnecessary server calls and keeps faulty data out of
the database (ch. 4 Key Points). Forms are Cubit territory — no Bloc needed.

## Field classes (FormzInput)

Every form field is a `FormzInput<ValueType, ErrorEnum>` subclass with two
constructors — the book calls them **unvalidated** (pure) and **validated** (dirty):

```dart
import 'package:formz/formz.dart';

class Email extends FormzInput<String, EmailValidationError> {
  const Email.unvalidated([super.value = '']) : isAlreadyRegistered = false, super.pure();

  const Email.validated(super.value, {this.isAlreadyRegistered = false}) : super.dirty();

  static final _emailRegex = RegExp(r'^[a-zA-Z\d.+_-]+@[a-zA-Z\d.-]+\.[a-zA-Z]+$');

  final bool isAlreadyRegistered;

  @override
  EmailValidationError? validator(String value) => value.isEmpty
      ? EmailValidationError.empty
      : (isAlreadyRegistered
          ? EmailValidationError.alreadyRegistered
          : (_emailRegex.hasMatch(value) ? null : EmailValidationError.invalid));
}

enum EmailValidationError { empty, invalid, alreadyRegistered }
```

- One `ValidationError` enum per field.
- Fields used by ≥2 features live in `lib/form_fields/`; single-feature fields stay
  in the feature's `src/`.

## Validation triggers — lazy-then-eager

Deciding **when** to validate is the key design decision. The robust approach
(ch. 4): validate on **focus loss** and on **submit**; once a field is already
invalid, re-validate eagerly on every keystroke so the error clears the moment the
input becomes valid.

Cubit methods per field:

```dart
void onEmailChanged(String newValue) {
  final previous = state.email;
  final shouldValidate = previous.isNotValid; // dirty + invalid → eager
  emit(state.copyWith(
    email: shouldValidate ? Email.validated(newValue) : Email.unvalidated(newValue),
  ));
}

void onEmailUnfocused() =>
    emit(state.copyWith(email: Email.validated(state.email.value)));
```

Wire focus loss from the View (StatefulWidget owning the `FocusNode`s — UI-only
state stays in the widget, never in the Cubit):

```dart
_emailFocusNode.addListener(() {
  if (!_emailFocusNode.hasFocus) cubit.onEmailUnfocused();
});
```

## Submit

Validate everything, bail if invalid, then run the async work through
`SubmissionStatus`:

```dart
Future<void> onSubmit() async {
  final email = Email.validated(state.email.value);
  final password = Password.validated(state.password.value);
  final isValid = Formz.validate([email, password]);
  emit(state.copyWith(email: email, password: password));
  if (!isValid) return;

  emit(state.copyWith(submissionStatus: SubmissionStatus.inProgress));
  try {
    await userRepository.signIn(email.value, password.value);
    emit(state.copyWith(submissionStatus: SubmissionStatus.success));
  } on InvalidCredentialsException {
    emit(state.copyWith(submissionStatus: SubmissionStatus.invalidCredentialsError));
  } catch (_) {
    emit(state.copyWith(submissionStatus: SubmissionStatus.genericError));
  }
}
```

## Server-side rejection feedback

For values the server can reject (email/username already taken): put a boolean flag
on the field class (`isAlreadyRegistered`), set it from the Cubit when the domain
exception arrives — re-validating the same value so the field now reports the
server-driven error — and reset it when the user edits the value:

```dart
} on EmailAlreadyRegisteredException {
  emit(state.copyWith(
    email: Email.validated(state.email.value, isAlreadyRegistered: true),
    submissionStatus: SubmissionStatus.idle,
  ));
}
```

## Error display

Map the error enum to localized strings in the View; `null` means no error:

```dart
TextField(
  decoration: InputDecoration(
    labelText: l10n.emailTextFieldLabel,
    errorText: switch (state.email.displayError) {
      null => null,
      EmailValidationError.empty => l10n.emailTextFieldEmptyErrorMessage,
      EmailValidationError.invalid => l10n.emailTextFieldInvalidErrorMessage,
      EmailValidationError.alreadyRegistered => l10n.emailTextFieldAlreadyRegisteredErrorMessage,
    },
  ),
)
```

Disable inputs and swap the submit button for its in-progress variant while
`submissionStatus == inProgress`.

## Hard rules

- Every form field is a FormzInput — no ad-hoc `String` + validator functions.
- `copyWith` on the state class is what makes per-field updates cheap (ch. 4 Key
  Points).
- `FocusNode`s, `TextEditingController`s and other ephemeral UI state live in the
  View's `State`, never in the Cubit.
- Optional-field variants (`OptionalPassword` for update-profile flows) are their
  own FormzInput classes, not nullable hacks.
- Confirmation fields (`PasswordConfirmation`) take the original field's value as a
  constructor argument to validate equality.
