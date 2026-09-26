import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/settings/src/settings_cubit.dart';
import 'package:radius/features/settings/src/settings_screen.dart';
import 'package:radius/l10n/l10n.dart';

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

void main() {
  late MockSettingsCubit cubit;
  var back = false;
  var forgotten = 0;

  setUpAll(() => registerFallbackValue(DarkModePreference.alwaysLight));

  setUp(() {
    cubit = MockSettingsCubit();
    back = false;
    forgotten = 0;
    when(() => cubit.onDarkModeSelected(any())).thenAnswer((_) async {});
    when(cubit.onForgetConfirmed).thenAnswer((_) async {});
    when(cubit.onForgetAnyway).thenAnswer((_) async {});
    when(cubit.onForgetAbandoned).thenReturn(null);
  });

  Widget host() => AppTheme(
    lightTheme: LightAppThemeData(),
    darkTheme: DarkAppThemeData(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: LightAppThemeData().materialThemeData,
      home: BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: SettingsView(
          onBackPressed: () => back = true,
          onIdentityForgotten: () => forgotten++,
        ),
      ),
    ),
  );

  const me = Identity(
    peerId: '0011223344556677',
    shortId: 'K7QA',
    npub: 'npub1xyz',
    origin: IdentityOrigin.restored,
  );

  testWidgets('shows the identity, the npub and the mode picker', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<SettingsState>.empty(),
      initialState: const SettingsState(identity: me),
    );
    await tester.pumpWidget(host());
    expect(find.text('You are K7QA'), findsOneWidget);
    expect(find.text('npub1xyz'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('picking a mode tells the cubit', (tester) async {
    whenListen(
      cubit,
      const Stream<SettingsState>.empty(),
      initialState: const SettingsState(identity: me),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.text('Dark'));
    verify(
      () => cubit.onDarkModeSelected(DarkModePreference.alwaysDark),
    ).called(1);
  });

  testWidgets('forgetting asks first and only proceeds on yes', (tester) async {
    whenListen(
      cubit,
      const Stream<SettingsState>.empty(),
      initialState: const SettingsState(identity: me),
    );
    await tester.pumpWidget(host());
    // Far enough down a lazy list that it is not built until scrolled to.
    await tester.scrollUntilVisible(
      find.text('Forget my identity'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget my identity'));
    await tester.pumpAndSettle();
    expect(find.text('Forget this identity?'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    verifyNever(cubit.onForgetConfirmed);

    await tester.tap(find.text('Forget my identity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, forget it'));
    await tester.pumpAndSettle();
    verify(cubit.onForgetConfirmed).called(1);
  });

  testWidgets('once forgotten, tells the app and shows it', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable([
        const SettingsState(
          identity: me,
          forgetStatus: ForgetStatus.inProgress,
        ),
        const SettingsState(identity: me, forgetStatus: ForgetStatus.done),
      ]),
      initialState: const SettingsState(identity: me),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    expect(forgotten, 1);
    expect(find.text('Identity forgotten'), findsOneWidget);
    expect(find.text('Forget my identity'), findsNothing);
  });

  testWidgets('back goes back', (tester) async {
    whenListen(
      cubit,
      const Stream<SettingsState>.empty(),
      initialState: const SettingsState(),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(back, isTrue);
  });

  testWidgets('when nobody can hear, says what stays and offers both ways', (
    tester,
  ) async {
    const stranded = RetirementOutlook(
      openBountyTitles: ['Carry a booth'],
      pendingClaimCount: 1,
      canAnnounce: false,
    );
    whenListen(
      cubit,
      Stream.fromIterable([
        const SettingsState(
          identity: me,
          forgetStatus: ForgetStatus.inProgress,
        ),
        const SettingsState(
          identity: me,
          forgetStatus: ForgetStatus.unreachable,
          outlook: stranded,
        ),
      ]),
      initialState: const SettingsState(identity: me),
    );
    when(() => cubit.state).thenReturn(
      const SettingsState(
        identity: me,
        forgetStatus: ForgetStatus.unreachable,
        outlook: stranded,
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Nobody can hear you right now'), findsOneWidget);
    expect(find.text('Still open: Carry a booth'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    verify(cubit.onForgetAbandoned).called(1);
    verifyNever(cubit.onForgetAnyway);
  });
}
