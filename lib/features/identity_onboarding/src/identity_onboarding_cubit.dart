import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';

part 'identity_onboarding_state.dart';

/// Three pages on first launch, and one flag when they are done.
///
/// The identity already exists by the time this runs; it was made the moment
/// the app started. The point of the screens is to say so, show the label
/// people will know this phone by, and explain why Bluetooth is about to be
/// asked for.
class IdentityOnboardingCubit extends Cubit<IdentityOnboardingState> {
  IdentityOnboardingCubit({required IdentityRepository identityRepository})
    : _repository = identityRepository,
      super(const IdentityOnboardingState()) {
    _loadIdentity();
  }

  final IdentityRepository _repository;

  static const pageCount = 3;

  Future<void> _loadIdentity() async {
    try {
      final identity = await _repository.getIdentity();
      if (!isClosed) emit(state.copyWith(identity: identity));
    } on IdentityLoadException {
      if (!isClosed) emit(state.copyWith(identityFailed: true));
    }
  }

  void onNext() {
    if (state.page < pageCount - 1) emit(state.copyWith(page: state.page + 1));
  }

  void onPageChanged(int page) => emit(state.copyWith(page: page));

  Future<void> onFinish() async {
    if (state.status == OnboardingStatus.finishing) return;
    emit(state.copyWith(status: OnboardingStatus.finishing));
    try {
      await _repository.markOnboarded();
      emit(state.copyWith(status: OnboardingStatus.finished));
    } on PreferencesException {
      // Not worth stopping anyone over: the screens will show once more on
      // the next launch, and that is the whole cost.
      emit(state.copyWith(status: OnboardingStatus.finished));
    }
  }
}
