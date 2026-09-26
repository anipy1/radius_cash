import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/form_fields/form_fields.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';

part 'bounty_create_state.dart';

/// The post-a-bounty form. Lazy validation until a field has been wrong
/// once, then eager, so an error clears the moment the input is fixed.
class BountyCreateCubit extends Cubit<BountyCreateState> {
  BountyCreateCubit({
    required BountyRepository bountyRepository,
    required LocationRepository locationRepository,
    DateTime Function()? clock,
  }) : _repository = bountyRepository,
       _location = locationRepository,
       _now = clock ?? DateTime.now,
       super(BountyCreateState.initial((clock ?? DateTime.now)()));

  final BountyRepository _repository;
  final LocationRepository _location;
  final DateTime Function() _now;

  /// How long to wait for a position before posting without one.
  static const locationTimeout = Duration(seconds: 20);

  void onTitleChanged(String value) => emit(
    state.copyWith(
      title: state.title.isNotValid
          ? BountyTitle.validated(value)
          : BountyTitle.unvalidated(value),
    ),
  );

  void onTitleUnfocused() =>
      emit(state.copyWith(title: BountyTitle.validated(state.title.value)));

  void onDetailsChanged(String value) => emit(
    state.copyWith(
      details: state.details.isNotValid
          ? BountyDetails.validated(value)
          : BountyDetails.unvalidated(value),
    ),
  );

  void onDetailsUnfocused() => emit(
    state.copyWith(details: BountyDetails.validated(state.details.value)),
  );

  void onAmountChanged(String value) => emit(
    state.copyWith(
      amount: state.amount.isNotValid
          ? EuroAmount.validated(value)
          : EuroAmount.unvalidated(value),
    ),
  );

  void onAmountUnfocused() =>
      emit(state.copyWith(amount: EuroAmount.validated(state.amount.value)));

  /// One of the offered durations from now.
  void onExpiryPresetSelected(Duration preset) {
    final now = _now();
    emit(
      state.copyWith(
        expiry: BountyExpiry.validated(now.add(preset), now: now),
        expiryPreset: preset,
      ),
    );
  }

  /// A moment the user picked themselves.
  void onExpiryPicked(DateTime value) {
    final now = _now();
    emit(
      state.copyWith(
        expiry: BountyExpiry.validated(value, now: now),
        clearPreset: true,
      ),
    );
  }

  /// Back to idle after the view has shown an error, so the user can retry.
  void onErrorShown() =>
      emit(state.copyWith(submissionStatus: SubmissionStatus.idle));

  Future<void> onSubmit() async {
    final now = _now();
    final title = BountyTitle.validated(state.title.value);
    final details = BountyDetails.validated(state.details.value);
    final amount = EuroAmount.validated(state.amount.value);
    final expiry = BountyExpiry.validated(state.expiry.value, now: now);
    final isValid = Formz.validate([title, details, amount, expiry]);
    emit(
      state.copyWith(
        title: title,
        details: details,
        amount: amount,
        expiry: expiry,
      ),
    );
    if (!isValid) return;

    emit(state.copyWith(submissionStatus: SubmissionStatus.inProgress));
    // One fix, so the listing can be found by area over the internet. No
    // fix, no permission or no patience: the bounty goes out anyway, radio
    // only, which is what it was always going to be first.
    Geohash? geohash;
    try {
      geohash = await _location.currentGeohash().timeout(locationTimeout);
    } catch (_) {
      geohash = null;
    }
    try {
      final bounty = await _repository.postBounty(
        title: title.value,
        details: details.value,
        amountCents: amount.cents!,
        expiresAt: expiry.value,
        geohash: geohash,
      );
      emit(
        state.copyWith(
          submissionStatus: SubmissionStatus.success,
          postedBountyId: bounty.id,
        ),
      );
    } on BountyValidationException {
      emit(state.copyWith(submissionStatus: SubmissionStatus.validationError));
    } on MeshNotRunningException {
      emit(
        state.copyWith(submissionStatus: SubmissionStatus.meshNotRunningError),
      );
    } on BountySendException {
      emit(state.copyWith(submissionStatus: SubmissionStatus.sendError));
    } on BountyCacheException {
      emit(state.copyWith(submissionStatus: SubmissionStatus.cacheError));
    } catch (_) {
      emit(state.copyWith(submissionStatus: SubmissionStatus.genericError));
    }
  }
}
