import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/bounty_feed/src/bounty_feed_bloc.dart';
import 'package:radius/features/bounty_feed/src/bounty_feed_screen.dart';
import 'package:radius/l10n/l10n.dart';

class MockBountyFeedBloc extends MockBloc<BountyFeedEvent, BountyFeedState>
    implements BountyFeedBloc {}

void main() {
  late MockBountyFeedBloc bloc;
  String? selected;
  var postTapped = false;

  setUp(() {
    bloc = MockBountyFeedBloc();
    selected = null;
    postTapped = false;
  });

  Widget host() => AppTheme(
    lightTheme: LightAppThemeData(),
    darkTheme: DarkAppThemeData(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: LightAppThemeData().materialThemeData,
      home: BlocProvider<BountyFeedBloc>.value(
        value: bloc,
        child: BountyFeedView(
          onBountySelected: (id) => selected = id,
          onPostBountyTapped: () => postTapped = true,
          onPeersTapped: () {},
          onSettingsTapped: () {},
        ),
      ),
    ),
  );

  final open = Bounty(
    id: 'b1',
    authorId: 'them',
    authorLabel: 'K7QA',
    isMine: false,
    title: 'Carry a booth to hall B',
    details: 'Two people.',
    amountCents: 2500,
    createdAt: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 3)),
    updatedAt: DateTime.now(),
    status: BountyStatus.open,
    claimantId: null,
    claimantLabel: null,
  );

  testWidgets('When nothing is nearby, shows the empty state and post button', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<BountyFeedState>.empty(),
      initialState: const BountyFeedState(startStatus: MeshStartStatus.started),
    );
    await tester.pumpWidget(host());
    expect(find.text('Nothing nearby yet'), findsOneWidget);

    await tester.tap(find.text('Post bounty'));
    expect(postTapped, isTrue);
  });

  testWidgets('When a bounty is nearby, its card shows and taps through', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<BountyFeedState>.empty(),
      initialState: BountyFeedState(
        startStatus: MeshStartStatus.started,
        bounties: [open],
        meshStatus: const MeshStatus(
          phase: MeshPhase.running,
          peerCount: 1,
          nearbyDeviceCount: 1,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Carry a booth to hall B'), findsOneWidget);
    expect(find.text('€25'), findsOneWidget);
    expect(find.text('1 peer in range'), findsOneWidget);

    await tester.tap(find.text('Carry a booth to hall B'));
    expect(selected, 'b1');
  });

  testWidgets(
    'When the radio failed for permission, explains and offers retry',
    (tester) async {
      whenListen(
        bloc,
        const Stream<BountyFeedState>.empty(),
        initialState: const BountyFeedState(
          startStatus: MeshStartStatus.failed,
          meshStatus: MeshStatus(
            phase: MeshPhase.unauthorized,
            peerCount: 0,
            nearbyDeviceCount: 0,
          ),
        ),
      );
      await tester.pumpWidget(host());
      expect(find.text('The radio could not start'), findsOneWidget);
      expect(find.textContaining('permission'), findsWidgets);
      await tester.tap(find.text('Try again'));
      verify(() => bloc.add(const BountyFeedRetryRequested())).called(1);
    },
  );

  testWidgets('When the poster has gone quiet, the card says so', (
    tester,
  ) async {
    final quiet = Bounty(
      id: 'b2',
      authorId: 'them',
      authorLabel: 'K7QA',
      isMine: false,
      title: 'Carry a booth to hall B',
      details: '',
      amountCents: 2500,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      expiresAt: DateTime.now().add(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(Bounty.posterLease),
      status: BountyStatus.open,
      claimantId: null,
      claimantLabel: null,
      viaInternet: true,
    );
    whenListen(
      bloc,
      const Stream<BountyFeedState>.empty(),
      initialState: BountyFeedState(
        startStatus: MeshStartStatus.started,
        bounties: [quiet],
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('poster away'), findsOneWidget);
    // Away outranks online: the path it came by matters less than the
    // fact that nobody is at the other end of it.
    expect(find.text('online'), findsNothing);
  });

  testWidgets('When a segment is tapped, the bloc hears about it', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<BountyFeedState>.empty(),
      initialState: const BountyFeedState(startStatus: MeshStartStatus.started),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.text('Mine'));
    verify(
      () => bloc.add(const BountyFeedSegmentChanged(BountyFeedSegment.mine)),
    ).called(1);
  });

  testWidgets('When on Claimed, a card says where my offer stands', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<BountyFeedState>.empty(),
      initialState: BountyFeedState(
        startStatus: MeshStartStatus.started,
        segment: BountyFeedSegment.claimed,
        bounties: [open],
        claims: [
          Claim(
            bountyId: 'b1',
            claimantId: 'me',
            claimantLabel: 'MEME',
            note: '',
            sentAt: DateTime.now(),
            status: ClaimStatus.accepted,
            isMine: true,
          ),
        ],
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('yours'), findsOneWidget);
  });

  group('the witness badge', () {
    // A finished bounty only appears under 'mine' or 'claimed': the nearby
    // segment is open bounties from other people, so a done one is never
    // there. This is the author looking at their own.
    Bounty done({List<String> witnessLabels = const []}) => Bounty(
      id: 'b9',
      authorId: 'me',
      authorLabel: 'K7QA',
      isMine: true,
      title: 'Carry a booth to hall B',
      details: '',
      amountCents: 2500,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      expiresAt: DateTime.now().add(const Duration(hours: 3)),
      updatedAt: DateTime.now(),
      status: BountyStatus.done,
      claimantId: 'zz',
      claimantLabel: 'ZZ9P',
      witnessLabels: witnessLabels,
    );

    Future<void> show(WidgetTester tester, Bounty bounty) async {
      whenListen(
        bloc,
        const Stream<BountyFeedState>.empty(),
        initialState: BountyFeedState(
          startStatus: MeshStartStatus.started,
          segment: BountyFeedSegment.mine,
          bounties: [bounty],
        ),
      );
      await tester.pumpWidget(host());
    }

    testWidgets('When witnesses signed, the card counts them', (tester) async {
      await show(tester, done(witnessLabels: const ['ZZ9P', 'M4TB', 'K7QA']));

      expect(find.text('3 witnesses'), findsOneWidget);
      // Next to the status badge, not instead of it.
      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('When one signed, the badge is singular', (tester) async {
      await show(tester, done(witnessLabels: const ['ZZ9P']));
      expect(find.text('1 witness'), findsOneWidget);
    });

    testWidgets('When nobody signed, there is no badge', (tester) async {
      await show(tester, done());

      // "0 witnesses" on a card would be noise; the detail screen is where
      // the absence is spelled out.
      expect(find.textContaining('witness'), findsNothing);
      expect(find.text('done'), findsOneWidget);
    });
  });
}
