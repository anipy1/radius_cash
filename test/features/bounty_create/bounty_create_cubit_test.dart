import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/bounty_create/src/bounty_create_cubit.dart';
import 'package:radius/form_fields/form_fields.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';

class MockBountyRepository extends Mock implements BountyRepository {}

class MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  group('BountyCreateCubit:', () {
    final now = DateTime.utc(2026, 9, 26, 12);
    late MockBountyRepository repository;
    late MockLocationRepository location;

    setUp(() {
      repository = MockBountyRepository();
      location = MockLocationRepository();
      when(
        location.currentGeohash,
      ).thenAnswer((_) async => const Geohash('ud9d5'));
      registerFallbackValue(now);
      registerFallbackValue(const Geohash('u'));
    });

    BountyCreateCubit build() => BountyCreateCubit(
      bountyRepository: repository,
      locationRepository: location,
      clock: () => now,
    );

    final posted = Bounty(
      id: 'abc',
      authorId: 'me',
      authorLabel: 'MEME',
      isMine: true,
      title: 'Carry',
      details: '',
      amountCents: 2500,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      updatedAt: now,
      status: BountyStatus.open,
      claimantId: null,
      claimantLabel: null,
    );

    BountyCreateState filled() => BountyCreateState.initial(now).copyWith(
      title: const BountyTitle.unvalidated('Carry'),
      amount: const EuroAmount.unvalidated('25'),
    );

    test('When created, the default expiry is 24 hours from now', () {
      final cubit = build();
      expect(cubit.state.expiry.value, now.add(const Duration(hours: 24)));
      expect(cubit.state.expiryPreset, const Duration(hours: 24));
    });

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When a field is untouched, typing does not validate; unfocusing does',
      build: build,
      act: (cubit) => cubit
        ..onTitleChanged('Carry')
        ..onTitleChanged('')
        ..onTitleUnfocused(),
      expect: () => [
        isA<BountyCreateState>().having(
          (s) => s.title.displayError,
          'error',
          isNull,
        ),
        isA<BountyCreateState>().having(
          (s) => s.title.displayError,
          'error',
          isNull,
        ),
        isA<BountyCreateState>().having(
          (s) => s.title.displayError,
          'error',
          BountyTitleValidationError.empty,
        ),
      ],
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When a field was wrong once, typing re-validates eagerly',
      build: build,
      seed: () => BountyCreateState.initial(
        now,
      ).copyWith(title: const BountyTitle.validated('')),
      act: (cubit) => cubit.onTitleChanged('Fix it'),
      expect: () => [
        isA<BountyCreateState>()
            .having((s) => s.title.displayError, 'error', isNull)
            .having((s) => s.title.isValid, 'valid', isTrue),
      ],
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When submitted with an empty title, validates and stops',
      build: build,
      act: (cubit) => cubit.onSubmit(),
      expect: () => [
        isA<BountyCreateState>()
            .having(
              (s) => s.title.displayError,
              'title',
              BountyTitleValidationError.empty,
            )
            .having(
              (s) => s.amount.displayError,
              'amount',
              EuroAmountValidationError.empty,
            )
            .having((s) => s.submissionStatus, 'status', SubmissionStatus.idle),
      ],
      verify: (_) => verifyNever(
        () => repository.postBounty(
          title: any(named: 'title'),
          details: any(named: 'details'),
          amountCents: any(named: 'amountCents'),
          expiresAt: any(named: 'expiresAt'),
          geohash: any(named: 'geohash'),
        ),
      ),
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When submitted and posted, emits inProgress then success with the id',
      setUp: () => when(
        () => repository.postBounty(
          title: 'Carry',
          details: '',
          amountCents: 2500,
          expiresAt: now.add(const Duration(hours: 24)),
          geohash: const Geohash('ud9d5'),
        ),
      ).thenAnswer((_) async => posted),
      build: build,
      seed: filled,
      act: (cubit) => cubit.onSubmit(),
      expect: () => [
        isA<BountyCreateState>().having(
          (s) => s.submissionStatus,
          'status',
          SubmissionStatus.idle,
        ),
        isA<BountyCreateState>().having(
          (s) => s.submissionStatus,
          'status',
          SubmissionStatus.inProgress,
        ),
        isA<BountyCreateState>()
            .having(
              (s) => s.submissionStatus,
              'status',
              SubmissionStatus.success,
            )
            .having((s) => s.postedBountyId, 'id', 'abc'),
      ],
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When no position can be had, posts without one',
      setUp: () {
        when(
          location.currentGeohash,
        ).thenAnswer((_) async => throw LocationPermissionDeniedException());
        when(
          () => repository.postBounty(
            title: 'Carry',
            details: '',
            amountCents: 2500,
            expiresAt: now.add(const Duration(hours: 24)),
            geohash: null,
          ),
        ).thenAnswer((_) async => posted);
      },
      build: build,
      seed: filled,
      act: (cubit) => cubit.onSubmit(),
      expect: () => [
        isA<BountyCreateState>(),
        isA<BountyCreateState>().having(
          (s) => s.submissionStatus,
          'status',
          SubmissionStatus.inProgress,
        ),
        isA<BountyCreateState>().having(
          (s) => s.submissionStatus,
          'status',
          SubmissionStatus.success,
        ),
      ],
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When the mesh is not running, says so',
      setUp: () => when(
        () => repository.postBounty(
          title: any(named: 'title'),
          details: any(named: 'details'),
          amountCents: any(named: 'amountCents'),
          expiresAt: any(named: 'expiresAt'),
          geohash: any(named: 'geohash'),
        ),
      ).thenThrow(MeshNotRunningException()),
      build: build,
      seed: filled,
      act: (cubit) => cubit.onSubmit(),
      expect: () => [
        isA<BountyCreateState>(),
        isA<BountyCreateState>().having(
          (s) => s.submissionStatus,
          'status',
          SubmissionStatus.inProgress,
        ),
        isA<BountyCreateState>().having(
          (s) => s.submissionStatus,
          'status',
          SubmissionStatus.meshNotRunningError,
        ),
      ],
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When a preset is chosen, expiry moves and the chip lights',
      build: build,
      act: (cubit) => cubit.onExpiryPresetSelected(const Duration(hours: 1)),
      expect: () => [
        isA<BountyCreateState>()
            .having(
              (s) => s.expiry.value,
              'expiry',
              now.add(const Duration(hours: 1)),
            )
            .having((s) => s.expiryPreset, 'preset', const Duration(hours: 1)),
      ],
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When a custom moment is picked, no preset is lit and the past is an error',
      build: build,
      act: (cubit) =>
          cubit.onExpiryPicked(now.subtract(const Duration(minutes: 1))),
      expect: () => [
        isA<BountyCreateState>()
            .having((s) => s.expiryPreset, 'preset', isNull)
            .having(
              (s) => s.expiry.displayError,
              'error',
              BountyExpiryValidationError.inThePast,
            ),
      ],
    );

    blocTest<BountyCreateCubit, BountyCreateState>(
      'When an error was shown, status returns to idle',
      build: build,
      seed: () => BountyCreateState.initial(
        now,
      ).copyWith(submissionStatus: SubmissionStatus.sendError),
      act: (cubit) => cubit.onErrorShown(),
      expect: () => [
        isA<BountyCreateState>().having(
          (s) => s.submissionStatus,
          'status',
          SubmissionStatus.idle,
        ),
      ],
    );
  });
}
