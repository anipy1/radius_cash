import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/features/bounty_create/src/bounty_create_cubit.dart';
import 'package:radius/features/bounty_create/src/bounty_create_screen.dart';
import 'package:radius/form_fields/form_fields.dart';
import 'package:radius/l10n/l10n.dart';

class MockBountyCreateCubit extends MockCubit<BountyCreateState>
    implements BountyCreateCubit {}

void main() {
  final now = DateTime(2026, 9, 26, 12);
  late MockBountyCreateCubit cubit;
  String? posted;
  var cancelled = false;

  setUpAll(() => registerFallbackValue(Duration.zero));

  setUp(() {
    cubit = MockBountyCreateCubit();
    posted = null;
    cancelled = false;
    when(() => cubit.onTitleChanged(any())).thenReturn(null);
    when(() => cubit.onAmountChanged(any())).thenReturn(null);
    when(() => cubit.onDetailsChanged(any())).thenReturn(null);
    when(() => cubit.onTitleUnfocused()).thenReturn(null);
    when(() => cubit.onAmountUnfocused()).thenReturn(null);
    when(() => cubit.onDetailsUnfocused()).thenReturn(null);
    when(() => cubit.onExpiryPresetSelected(any())).thenReturn(null);
    when(() => cubit.onErrorShown()).thenReturn(null);
    when(() => cubit.onSubmit()).thenAnswer((_) async {});
  });

  Widget host() => AppTheme(
    lightTheme: LightAppThemeData(),
    darkTheme: DarkAppThemeData(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: LightAppThemeData().materialThemeData,
      home: BlocProvider<BountyCreateCubit>.value(
        value: cubit,
        child: BountyCreateView(
          onBountyPosted: (id) => posted = id,
          onCancelled: () => cancelled = true,
        ),
      ),
    ),
  );

  testWidgets('When typing, the cubit hears each field', (tester) async {
    whenListen(
      cubit,
      const Stream<BountyCreateState>.empty(),
      initialState: BountyCreateState.initial(now),
    );
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField).at(0), 'Carry');
    await tester.enterText(find.byType(TextField).at(1), '25');
    verify(() => cubit.onTitleChanged('Carry')).called(1);
    verify(() => cubit.onAmountChanged('25')).called(1);
  });

  testWidgets('When a field has an error, it is shown in words', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<BountyCreateState>.empty(),
      initialState: BountyCreateState.initial(now).copyWith(
        title: const BountyTitle.validated(''),
        amount: const EuroAmount.validated('abc'),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('A title is needed.'), findsOneWidget);
    expect(find.text('Enter an amount like 25 or 12.50.'), findsOneWidget);
  });

  testWidgets('When a preset chip is tapped, the cubit is told', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<BountyCreateState>.empty(),
      initialState: BountyCreateState.initial(now),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.text('1 h'));
    verify(
      () => cubit.onExpiryPresetSelected(const Duration(hours: 1)),
    ).called(1);
  });

  testWidgets('When submitting, the button turns into progress', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<BountyCreateState>.empty(),
      initialState: BountyCreateState.initial(
        now,
      ).copyWith(submissionStatus: SubmissionStatus.inProgress),
    );
    await tester.pumpWidget(host());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('When posted, the callback fires with the id', (tester) async {
    whenListen(
      cubit,
      Stream.fromIterable([
        BountyCreateState.initial(now).copyWith(
          submissionStatus: SubmissionStatus.success,
          postedBountyId: 'xyz',
        ),
      ]),
      initialState: BountyCreateState.initial(now),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(posted, 'xyz');
  });

  testWidgets('When sending fails, a snackbar says so and status resets', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream.fromIterable([
        BountyCreateState.initial(
          now,
        ).copyWith(submissionStatus: SubmissionStatus.sendError),
      ]),
      initialState: BountyCreateState.initial(now),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(
      find.text('The radio would not take it. Try again.'),
      findsOneWidget,
    );
    verify(() => cubit.onErrorShown()).called(1);
  });

  testWidgets('When cancel is tapped, the callback fires', (tester) async {
    whenListen(
      cubit,
      const Stream<BountyCreateState>.empty(),
      initialState: BountyCreateState.initial(now),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.bySemanticsLabel('Cancel'));
    expect(cancelled, isTrue);
  });
}
