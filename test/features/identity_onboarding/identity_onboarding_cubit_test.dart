import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/identity_onboarding/src/identity_onboarding_cubit.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';

class MockIdentityRepository extends Mock implements IdentityRepository {}

void main() {
  group('IdentityOnboardingCubit:', () {
    late MockIdentityRepository repository;
    const identity = Identity(
      peerId: '0011223344556677',
      shortId: 'K7QA',
      npub: 'npub1abc',
      origin: IdentityOrigin.created,
    );

    setUp(() {
      repository = MockIdentityRepository();
      when(repository.getIdentity).thenAnswer((_) async => identity);
      when(repository.markOnboarded).thenAnswer((_) async {});
    });

    IdentityOnboardingCubit build() =>
        IdentityOnboardingCubit(identityRepository: repository);

    blocTest<IdentityOnboardingCubit, IdentityOnboardingState>(
      'When created, loads the identity',
      build: build,
      expect: () => [const IdentityOnboardingState(identity: identity)],
    );

    blocTest<IdentityOnboardingCubit, IdentityOnboardingState>(
      'When the identity cannot load, says so instead of hanging',
      setUp: () => when(
        repository.getIdentity,
      ).thenAnswer((_) async => throw IdentityLoadException()),
      build: build,
      expect: () => [const IdentityOnboardingState(identityFailed: true)],
    );

    blocTest<IdentityOnboardingCubit, IdentityOnboardingState>(
      'When next is tapped, advances and stops at the last page',
      build: build,
      seed: () => const IdentityOnboardingState(identity: identity),
      act: (cubit) => cubit
        ..onNext()
        ..onNext()
        ..onNext(),
      expect: () => [
        const IdentityOnboardingState(identity: identity, page: 1),
        const IdentityOnboardingState(identity: identity, page: 2),
      ],
    );

    blocTest<IdentityOnboardingCubit, IdentityOnboardingState>(
      'When finished, marks onboarding done and says finished',
      build: build,
      seed: () => const IdentityOnboardingState(identity: identity, page: 2),
      act: (cubit) => cubit.onFinish(),
      expect: () => [
        const IdentityOnboardingState(
          identity: identity,
          page: 2,
          status: OnboardingStatus.finishing,
        ),
        const IdentityOnboardingState(
          identity: identity,
          page: 2,
          status: OnboardingStatus.finished,
        ),
      ],
      verify: (_) => verify(repository.markOnboarded).called(1),
    );

    blocTest<IdentityOnboardingCubit, IdentityOnboardingState>(
      'When the preference cannot be saved, finishes anyway',
      setUp: () =>
          when(repository.markOnboarded).thenThrow(PreferencesException()),
      build: build,
      seed: () => const IdentityOnboardingState(identity: identity, page: 2),
      act: (cubit) => cubit.onFinish(),
      skip: 1,
      expect: () => [
        const IdentityOnboardingState(
          identity: identity,
          page: 2,
          status: OnboardingStatus.finished,
        ),
      ],
    );
  });
}
