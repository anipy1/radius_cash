import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/settings/src/settings_cubit.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';
import 'package:radius/repositories/settings_repository/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockIdentityRepository extends Mock implements IdentityRepository {}

class MockMeshRepository extends Mock implements MeshRepository {}

class MockBountyRepository extends Mock implements BountyRepository {}

void main() {
  group('SettingsCubit:', () {
    late MockSettingsRepository settings;
    late MockIdentityRepository identity;
    late MockMeshRepository mesh;
    late MockBountyRepository bounties;
    const me = Identity(
      peerId: '0011223344556677',
      shortId: 'K7QA',
      npub: 'npub1abc',
      origin: IdentityOrigin.restored,
    );

    setUpAll(() => registerFallbackValue(DarkModePreference.alwaysLight));

    setUp(() {
      settings = MockSettingsRepository();
      identity = MockIdentityRepository();
      mesh = MockMeshRepository();
      bounties = MockBountyRepository();
      when(bounties.retirementOutlook).thenAnswer(
        (_) async => const RetirementOutlook(
          openBountyTitles: ['Carry a booth'],
          pendingClaimCount: 0,
          canAnnounce: true,
        ),
      );
      when(() => bounties.retireIdentity()).thenAnswer((_) async {});
      when(
        settings.getDarkModePreference,
      ).thenAnswer((_) => Stream.value(DarkModePreference.alwaysDark));
      when(
        () => settings.setDarkModePreference(any()),
      ).thenAnswer((_) async {});
      when(identity.getIdentity).thenAnswer((_) async => me);
      when(identity.forgetIdentity).thenAnswer((_) async {});
      when(mesh.stop).thenAnswer((_) async {});
      when(mesh.stopRelays).thenAnswer((_) async {});
    });

    // What the cubit loads on its own. Seeding with the same state means the
    // load's emissions are no-ops and the act is the only thing observed.
    const loaded = SettingsState(
      darkMode: DarkModePreference.alwaysDark,
      identity: me,
    );

    SettingsCubit build() => SettingsCubit(
      settingsRepository: settings,
      identityRepository: identity,
      meshRepository: mesh,
      bountyRepository: bounties,
    );

    blocTest<SettingsCubit, SettingsState>(
      'When created, loads the preference and the identity',
      build: build,
      expect: () => [
        const SettingsState(darkMode: DarkModePreference.alwaysDark),
        const SettingsState(
          darkMode: DarkModePreference.alwaysDark,
          identity: me,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'When the identity cannot load, the rest of the screen still works',
      setUp: () => when(
        identity.getIdentity,
      ).thenAnswer((_) async => throw IdentityLoadException()),
      build: build,
      expect: () => [
        const SettingsState(darkMode: DarkModePreference.alwaysDark),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'When a mode is picked, it shows at once and is saved',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.onDarkModeSelected(DarkModePreference.alwaysLight),
      expect: () => [
        const SettingsState(
          darkMode: DarkModePreference.alwaysLight,
          identity: me,
        ),
      ],
      verify: (_) => verify(
        () => settings.setDarkModePreference(DarkModePreference.alwaysLight),
      ).called(1),
    );

    blocTest<SettingsCubit, SettingsState>(
      'When the save fails, the choice stays and the failure is shown',
      setUp: () => when(
        () => settings.setDarkModePreference(any()),
      ).thenThrow(PreferencesException()),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.onDarkModeSelected(DarkModePreference.alwaysLight),
      expect: () => [
        const SettingsState(
          darkMode: DarkModePreference.alwaysLight,
          identity: me,
        ),
        const SettingsState(
          darkMode: DarkModePreference.alwaysLight,
          identity: me,
          preferenceFailed: true,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'When forgetting is confirmed, the radio stops first and the seed goes',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.onForgetConfirmed(),
      expect: () => [
        const SettingsState(
          darkMode: DarkModePreference.alwaysDark,
          identity: me,
          forgetStatus: ForgetStatus.inProgress,
        ),
        const SettingsState(
          darkMode: DarkModePreference.alwaysDark,
          identity: me,
          forgetStatus: ForgetStatus.done,
        ),
      ],
      verify: (_) {
        // Closing what is open comes first, while the key still exists and
        // the transports are still up to carry it.
        verifyInOrder([
          () => bounties.retireIdentity(),
          mesh.stopRelays,
          mesh.stop,
          identity.forgetIdentity,
        ]);
      },
    );

    const stranded = RetirementOutlook(
      openBountyTitles: ['Carry a booth'],
      pendingClaimCount: 1,
      canAnnounce: false,
    );

    blocTest<SettingsCubit, SettingsState>(
      'When nothing can hear a cancellation and something is open, asks',
      setUp: () =>
          when(bounties.retirementOutlook).thenAnswer((_) async => stranded),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.onForgetConfirmed(),
      expect: () => [
        loaded.copyWith(forgetStatus: ForgetStatus.inProgress),
        loaded.copyWith(
          forgetStatus: ForgetStatus.unreachable,
          outlook: stranded,
        ),
      ],
      verify: (_) {
        verifyNever(() => bounties.retireIdentity());
        verifyNever(identity.forgetIdentity);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'When nothing can hear but nothing is open, goes straight ahead',
      setUp: () => when(bounties.retirementOutlook).thenAnswer(
        (_) async => const RetirementOutlook(
          openBountyTitles: [],
          pendingClaimCount: 0,
          canAnnounce: false,
        ),
      ),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.onForgetConfirmed(),
      expect: () => [
        loaded.copyWith(forgetStatus: ForgetStatus.inProgress),
        loaded.copyWith(forgetStatus: ForgetStatus.done),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'When told to forget anyway, retires what it can and erases',
      build: build,
      seed: () => loaded.copyWith(
        forgetStatus: ForgetStatus.unreachable,
        outlook: stranded,
      ),
      act: (cubit) => cubit.onForgetAnyway(),
      expect: () => [
        loaded.copyWith(
          forgetStatus: ForgetStatus.inProgress,
          outlook: stranded,
        ),
        loaded.copyWith(forgetStatus: ForgetStatus.done, outlook: stranded),
      ],
      verify: (_) => verify(() => bounties.retireIdentity()).called(1),
    );

    blocTest<SettingsCubit, SettingsState>(
      'When the person keeps it after all, nothing has changed',
      build: build,
      seed: () => loaded.copyWith(
        forgetStatus: ForgetStatus.unreachable,
        outlook: stranded,
      ),
      act: (cubit) => cubit.onForgetAbandoned(),
      expect: () => [
        loaded.copyWith(forgetStatus: ForgetStatus.idle, outlook: stranded),
      ],
      verify: (_) {
        verifyNever(() => bounties.retireIdentity());
        verifyNever(identity.forgetIdentity);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'When the seed will not erase, it says so and nothing is lost',
      setUp: () =>
          when(identity.forgetIdentity).thenThrow(IdentityForgetException()),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.onForgetConfirmed(),
      expect: () => [
        loaded.copyWith(forgetStatus: ForgetStatus.inProgress),
        loaded.copyWith(forgetStatus: ForgetStatus.failed),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'When the radio refuses to stop, the seed still goes',
      setUp: () => when(mesh.stop).thenThrow(MeshUnavailableException()),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.onForgetConfirmed(),
      expect: () => [
        loaded.copyWith(forgetStatus: ForgetStatus.inProgress),
        loaded.copyWith(forgetStatus: ForgetStatus.done),
      ],
    );
  });
}
