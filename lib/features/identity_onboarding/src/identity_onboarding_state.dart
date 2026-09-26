part of 'identity_onboarding_cubit.dart';

enum OnboardingStatus { idle, finishing, finished }

class IdentityOnboardingState extends Equatable {
  const IdentityOnboardingState({
    this.page = 0,
    this.identity,
    this.identityFailed = false,
    this.status = OnboardingStatus.idle,
  });

  final int page;

  /// Null until loaded.
  final Identity? identity;
  final bool identityFailed;
  final OnboardingStatus status;

  bool get isLastPage => page == IdentityOnboardingCubit.pageCount - 1;

  IdentityOnboardingState copyWith({
    int? page,
    Identity? identity,
    bool? identityFailed,
    OnboardingStatus? status,
  }) => IdentityOnboardingState(
    page: page ?? this.page,
    identity: identity ?? this.identity,
    identityFailed: identityFailed ?? this.identityFailed,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [page, identity, identityFailed, status];
}
