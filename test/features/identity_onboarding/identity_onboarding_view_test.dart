import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/identity_onboarding/src/identity_onboarding_cubit.dart';
import 'package:radius/features/identity_onboarding/src/identity_onboarding_screen.dart';
import 'package:radius/l10n/l10n.dart';

class MockIdentityOnboardingCubit extends MockCubit<IdentityOnboardingState>
    implements IdentityOnboardingCubit {}

void main() {
  late MockIdentityOnboardingCubit cubit;
  var finished = false;
  const identity = Identity(
    peerId: '0011223344556677',
    shortId: 'K7QA',
    npub: 'npub1abcdefghijklmnop',
    origin: IdentityOrigin.created,
  );

  setUp(() {
    cubit = MockIdentityOnboardingCubit();
    finished = false;
    when(cubit.onNext).thenReturn(null);
    when(() => cubit.onPageChanged(any())).thenReturn(null);
    when(cubit.onFinish).thenAnswer((_) async {});
  });

  Widget host() => AppTheme(
    lightTheme: LightAppThemeData(),
    darkTheme: DarkAppThemeData(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: LightAppThemeData().materialThemeData,
      home: BlocProvider<IdentityOnboardingCubit>.value(
        value: cubit,
        child: IdentityOnboardingView(onFinished: () => finished = true),
      ),
    ),
  );

  testWidgets('When on the first page, Next asks the cubit to advance', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<IdentityOnboardingState>.empty(),
      initialState: const IdentityOnboardingState(identity: identity),
    );
    await tester.pumpWidget(host());
    expect(find.text('Bounties for whoever is in range'), findsOneWidget);
    await tester.tap(find.text('Next'));
    verify(cubit.onNext).called(1);
  });

  testWidgets('When on the identity page, shows the label and the npub', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<IdentityOnboardingState>.empty(),
      initialState: const IdentityOnboardingState(identity: identity, page: 1),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('You are K7QA'), findsOneWidget);
    expect(find.text('npub1abcdefghijklmnop'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('When on the last page, the button finishes', (tester) async {
    whenListen(
      cubit,
      const Stream<IdentityOnboardingState>.empty(),
      initialState: const IdentityOnboardingState(identity: identity, page: 2),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on the radio'));
    verify(cubit.onFinish).called(1);
  });

  testWidgets('When finished, the callback fires', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable([
        const IdentityOnboardingState(
          identity: identity,
          page: 2,
          status: OnboardingStatus.finished,
        ),
      ]),
      initialState: const IdentityOnboardingState(identity: identity, page: 2),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(finished, isTrue);
  });
}
