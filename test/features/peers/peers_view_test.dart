import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/peers/src/peers_bloc.dart';
import 'package:radius/features/peers/src/peers_screen.dart';
import 'package:radius/l10n/l10n.dart';

class MockPeersBloc extends MockBloc<PeersEvent, PeersState>
    implements PeersBloc {}

void main() {
  late MockPeersBloc bloc;
  var back = false;

  setUp(() {
    bloc = MockPeersBloc();
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
      home: BlocProvider<PeersBloc>.value(
        value: bloc,
        child: PeersView(onBackPressed: () => back = true),
      ),
    ),
  );

  const me = Identity(
    peerId: '0011223344556677',
    shortId: 'K7QA',
    npub: 'npub1x',
    origin: IdentityOrigin.restored,
  );

  testWidgets('When nobody is around, says so and shows me', (tester) async {
    whenListen(
      bloc,
      const Stream<PeersState>.empty(),
      initialState: const PeersState(
        identity: me,
        meshStatus: MeshStatus(
          phase: MeshPhase.running,
          peerCount: 0,
          nearbyDeviceCount: 0,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('You are K7QA'), findsOneWidget);
    expect(find.text('Radio on'), findsOneWidget);
    expect(find.text('Nobody in range'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Back'));
    expect(back, isTrue);
  });

  testWidgets('When peers are around, lists them with their badges', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<PeersState>.empty(),
      initialState: const PeersState(
        identity: me,
        peers: [
          Peer(
            id: 'a',
            label: 'ZZ9P',
            hasSecureSession: true,
            reachableOnMesh: true,
            reachableViaInternet: true,
          ),
          Peer(
            id: 'b',
            label: 'MM2X',
            hasSecureSession: false,
            reachableOnMesh: false,
            reachableViaInternet: false,
          ),
        ],
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('2 phones in range'), findsOneWidget);
    expect(find.text('secure'), findsOneWidget);
    expect(find.text('online'), findsOneWidget);
    expect(find.text('Met before, out of range'), findsOneWidget);
  });
}
