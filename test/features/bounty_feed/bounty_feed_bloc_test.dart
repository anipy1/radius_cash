import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/bounty_feed/src/bounty_feed_bloc.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

class MockBountyRepository extends Mock implements BountyRepository {}

class MockMeshRepository extends Mock implements MeshRepository {}

class MockLocationRepository extends Mock implements LocationRepository {}

Bounty bounty(
  String id, {
  bool isMine = false,
  BountyStatus status = BountyStatus.open,
}) => Bounty(
  id: id,
  authorId: isMine ? 'me' : 'them',
  authorLabel: 'ABCD',
  isMine: isMine,
  title: 't',
  details: '',
  amountCents: 100,
  createdAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2027),
  updatedAt: DateTime.utc(2026),
  status: status,
  claimantId: null,
  claimantLabel: null,
);

void main() {
  group('BountyFeedBloc:', () {
    late MockBountyRepository bounties;
    late MockMeshRepository mesh;
    late MockLocationRepository location;
    late StreamController<List<Bounty>> bountyStream;
    late StreamController<List<Claim>> claimStream;
    late StreamController<MeshStatus> meshStream;
    late StreamController<RelayStatus> relayStream;
    late StreamController<BountyCacheException> failures;

    setUpAll(() => registerFallbackValue(const Geohash('u')));

    setUp(() {
      bounties = MockBountyRepository();
      mesh = MockMeshRepository();
      location = MockLocationRepository();
      when(
        location.currentGeohash,
      ).thenAnswer((_) async => throw LocationUnavailableException());
      bountyStream = StreamController();
      claimStream = StreamController();
      meshStream = StreamController();
      relayStream = StreamController();
      failures = StreamController();
      when(() => bounties.cacheFailures).thenAnswer((_) => failures.stream);
      when(bounties.getBounties).thenAnswer((_) => bountyStream.stream);
      when(bounties.getClaims).thenAnswer((_) => claimStream.stream);
      when(mesh.getMeshStatus).thenAnswer((_) => meshStream.stream);
      when(mesh.getRelayStatus).thenAnswer((_) => relayStream.stream);
      when(mesh.start).thenAnswer((_) async {});
      when(mesh.startRelays).thenAnswer((_) async {});
    });

    BountyFeedBloc build() => BountyFeedBloc(
      bountyRepository: bounties,
      meshRepository: mesh,
      locationRepository: location,
    );

    blocTest<BountyFeedBloc, BountyFeedState>(
      'When started, brings the mesh and then the relays up',
      build: build,
      act: (bloc) => bloc.add(const BountyFeedStarted()),
      expect: () => [
        const BountyFeedState(startStatus: MeshStartStatus.starting),
        const BountyFeedState(startStatus: MeshStartStatus.started),
      ],
      verify: (_) {
        verify(mesh.start).called(1);
        verify(mesh.startRelays).called(1);
      },
    );

    blocTest<BountyFeedBloc, BountyFeedState>(
      'When the radio will not start, reports failure and skips relays',
      setUp: () => when(mesh.start).thenThrow(MeshUnavailableException()),
      build: build,
      act: (bloc) => bloc.add(const BountyFeedStarted()),
      expect: () => [
        const BountyFeedState(startStatus: MeshStartStatus.starting),
        const BountyFeedState(startStatus: MeshStartStatus.failed),
      ],
      verify: (_) => verifyNever(mesh.startRelays),
    );

    blocTest<BountyFeedBloc, BountyFeedState>(
      'When relays fail, the screen does not',
      setUp: () =>
          when(mesh.startRelays).thenThrow(RelayUnavailableException()),
      build: build,
      act: (bloc) => bloc.add(const BountyFeedStarted()),
      expect: () => [
        const BountyFeedState(startStatus: MeshStartStatus.starting),
        const BountyFeedState(startStatus: MeshStartStatus.started),
      ],
    );

    blocTest<BountyFeedBloc, BountyFeedState>(
      'When repositories emit, the state follows',
      build: build,
      act: (bloc) async {
        bountyStream.add([bounty('a')]);
        meshStream.add(
          const MeshStatus(
            phase: MeshPhase.running,
            peerCount: 2,
            nearbyDeviceCount: 3,
          ),
        );
        relayStream.add(RelayStatus.connected);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<BountyFeedState>().having(
          (s) => s.bounties,
          'bounties',
          hasLength(1),
        ),
        isA<BountyFeedState>().having(
          (s) => s.meshStatus.peerCount,
          'peers',
          2,
        ),
        isA<BountyFeedState>().having(
          (s) => s.relayStatus,
          'relay',
          RelayStatus.connected,
        ),
      ],
    );

    blocTest<BountyFeedBloc, BountyFeedState>(
      'When the cache stream errors, the state says so',
      build: build,
      act: (bloc) async {
        failures.add(BountyCacheException());
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<BountyFeedState>().having(
          (s) => s.cacheFailed,
          'cacheFailed',
          true,
        ),
      ],
    );

    blocTest<BountyFeedBloc, BountyFeedState>(
      'When a position is had, the board follows that area',
      setUp: () {
        when(
          location.currentGeohash,
        ).thenAnswer((_) async => const Geohash('ud9d5'));
        when(() => bounties.followArea(any())).thenAnswer((_) async {});
      },
      build: build,
      act: (bloc) => bloc.add(const BountyFeedStarted()),
      verify: (_) =>
          verify(() => bounties.followArea(const Geohash('ud9d5'))).called(1),
    );

    test('Segments partition the board', () {
      final mine = bounty('m', isMine: true, status: BountyStatus.paid);
      final theirsOpen = bounty('o');
      final theirsClaimed = bounty('c', status: BountyStatus.claimed);
      final claim = Claim(
        bountyId: 'c',
        claimantId: 'me',
        claimantLabel: 'MEME',
        note: '',
        sentAt: DateTime.utc(2026),
        status: ClaimStatus.accepted,
        isMine: true,
      );
      final state = BountyFeedState(
        bounties: [mine, theirsOpen, theirsClaimed],
        claims: [claim],
      );

      expect(state.visible, [theirsOpen]);
      expect(state.copyWith(segment: BountyFeedSegment.mine).visible, [mine]);
      expect(state.copyWith(segment: BountyFeedSegment.claimed).visible, [
        theirsClaimed,
      ]);
    });
  });
}
