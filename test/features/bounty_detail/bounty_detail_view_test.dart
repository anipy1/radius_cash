import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/bounty_detail/src/bounty_detail_bloc.dart';
import 'package:radius/features/bounty_detail/src/bounty_detail_screen.dart';
import 'package:radius/l10n/l10n.dart';

class MockBountyDetailBloc
    extends MockBloc<BountyDetailEvent, BountyDetailState>
    implements BountyDetailBloc {}

void main() {
  late MockBountyDetailBloc bloc;
  var back = false;

  setUp(() {
    bloc = MockBountyDetailBloc();
    back = false;
  });

  Widget host() => AppTheme(
    lightTheme: LightAppThemeData(),
    darkTheme: DarkAppThemeData(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: LightAppThemeData().materialThemeData,
      home: BlocProvider<BountyDetailBloc>.value(
        value: bloc,
        child: BountyDetailView(onBackPressed: () => back = true),
      ),
    ),
  );

  Bounty bounty({
    bool isMine = false,
    BountyStatus status = BountyStatus.open,
    DateTime? updatedAt,
  }) => Bounty(
    id: 'b',
    authorId: isMine ? 'me' : 'them',
    authorLabel: 'K7QA',
    isMine: isMine,
    title: 'Carry a booth',
    details: 'Hall B',
    amountCents: 2550,
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 2)),
    updatedAt: updatedAt ?? DateTime.now(),
    status: status,
    claimantId: null,
    claimantLabel: null,
  );

  Claim claim({
    bool isMine = false,
    ClaimStatus status = ClaimStatus.pending,
    bool delivered = false,
  }) => Claim(
    bountyId: 'b',
    claimantId: isMine ? 'me' : 'zz',
    claimantLabel: 'ZZ9P',
    note: 'On my way',
    sentAt: DateTime.now(),
    status: status,
    isMine: isMine,
    delivered: delivered,
  );

  void seed(BountyDetailState state) => whenListen(
    bloc,
    const Stream<BountyDetailState>.empty(),
    initialState: state,
  );

  testWidgets('When loading, shows progress', (tester) async {
    seed(const BountyDetailInProgress());
    await tester.pumpWidget(host());
    expect(find.byType(ContraProgress), findsOneWidget);
  });

  testWidgets('When not found, says so and back works', (tester) async {
    seed(const BountyDetailFailure());
    await tester.pumpWidget(host());
    expect(find.text('Bounty not found'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(back, isTrue);
  });

  testWidgets('When someone else posted it, offers to claim with a note', (
    tester,
  ) async {
    seed(BountyDetailSuccess(bounty: bounty(), claims: const []));
    await tester.pumpWidget(host());
    expect(find.text('Carry a booth'), findsOneWidget);
    expect(find.text('€25.50'), findsOneWidget);
    expect(find.text('Posted by K7QA'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'five minutes');
    await tester.tap(find.text('Claim this bounty'));
    verify(
      () => bloc.add(const BountyDetailClaimRequested(note: 'five minutes')),
    ).called(1);
  });

  testWidgets('When the poster has gone quiet, warns but still offers', (
    tester,
  ) async {
    seed(
      BountyDetailSuccess(
        bounty: bounty(
          updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
        claims: const [],
      ),
    );
    await tester.pumpWidget(host());
    expect(
      find.textContaining('Nothing from the poster for 12'),
      findsOneWidget,
    );
    expect(find.text('Claim this bounty'), findsOneWidget);
  });

  testWidgets('A pending claim not yet delivered says so', (tester) async {
    seed(BountyDetailSuccess(bounty: bounty(), claims: [claim(isMine: true)]));
    await tester.pumpWidget(host());
    expect(find.textContaining('has not confirmed'), findsOneWidget);
  });

  testWidgets('A delivered claim says the poster\'s phone has it', (
    tester,
  ) async {
    seed(
      BountyDetailSuccess(
        bounty: bounty(),
        claims: [claim(isMine: true, delivered: true)],
      ),
    );
    await tester.pumpWidget(host());
    expect(find.textContaining('Delivered to the poster'), findsOneWidget);
  });

  testWidgets('When I already claimed, shows where it stands', (tester) async {
    seed(
      BountyDetailSuccess(
        bounty: bounty(status: BountyStatus.claimed),
        claims: [claim(isMine: true, status: ClaimStatus.accepted)],
      ),
    );
    await tester.pumpWidget(host());
    expect(find.textContaining('You are doing this one'), findsOneWidget);
    await tester.tap(find.text('I am done'));
    verify(() => bloc.add(const BountyDetailDoneRequested())).called(1);
  });

  testWidgets('When I posted it, lists claims with accept and decline', (
    tester,
  ) async {
    seed(BountyDetailSuccess(bounty: bounty(isMine: true), claims: [claim()]));
    await tester.pumpWidget(host());
    expect(find.text('1 claim'), findsOneWidget);
    expect(find.text('ZZ9P'), findsWidgets);
    expect(find.text('On my way'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Accept'));
    verify(() => bloc.add(const BountyDetailAcceptRequested('zz'))).called(1);
    await tester.tap(find.bySemanticsLabel('Decline'));
    verify(() => bloc.add(const BountyDetailDeclineRequested('zz'))).called(1);
    await tester.tap(find.text('Cancel bounty'));
    verify(() => bloc.add(const BountyDetailCancelRequested())).called(1);
  });

  testWidgets('When mine is claimed then done, offers done then paid', (
    tester,
  ) async {
    seed(
      BountyDetailSuccess(
        bounty: bounty(isMine: true, status: BountyStatus.claimed),
        claims: [claim(status: ClaimStatus.accepted)],
      ),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.text('Mark done'));
    verify(() => bloc.add(const BountyDetailDoneRequested())).called(1);

    // A mock bloc keeps its first stubbed state, so start a fresh one.
    bloc = MockBountyDetailBloc();
    seed(
      BountyDetailSuccess(
        bounty: bounty(isMine: true, status: BountyStatus.done),
        claims: [claim(status: ClaimStatus.done)],
      ),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.text('Mark paid'));
    verify(() => bloc.add(const BountyDetailPaidRequested())).called(1);
    expect(find.text('Cancel bounty'), findsNothing);
  });

  testWidgets('When an action fails, a snackbar says so', (tester) async {
    whenListen(
      bloc,
      Stream.fromIterable([
        BountyDetailSuccess(
          bounty: bounty(),
          claims: const [],
          actionStatus: ActionStatus.sendError,
        ),
      ]),
      initialState: BountyDetailSuccess(bounty: bounty(), claims: const []),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    expect(
      find.text('The radio would not take it. Try again.'),
      findsOneWidget,
    );
    verify(() => bloc.add(const BountyDetailErrorShown())).called(1);
  });
}
