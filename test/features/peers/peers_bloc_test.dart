import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/features/peers/src/peers_bloc.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

class MockMeshRepository extends Mock implements MeshRepository {}

class MockIdentityRepository extends Mock implements IdentityRepository {}

void main() {
  group('PeersBloc:', () {
    late MockMeshRepository mesh;
    late MockIdentityRepository identity;
    late StreamController<List<Peer>> peers;
    late StreamController<MeshStatus> status;
    late StreamController<RelayStatus> relay;
    const me = Identity(
      peerId: '0011223344556677',
      shortId: 'K7QA',
      npub: 'npub1x',
      origin: IdentityOrigin.restored,
    );
    const peer = Peer(
      id: 'ffeeddcc00112233',
      label: 'ZZ9P',
      hasSecureSession: true,
      reachableOnMesh: true,
      reachableViaInternet: false,
    );

    setUp(() {
      mesh = MockMeshRepository();
      identity = MockIdentityRepository();
      peers = StreamController();
      status = StreamController();
      relay = StreamController();
      when(mesh.getPeers).thenAnswer((_) => peers.stream);
      when(mesh.getMeshStatus).thenAnswer((_) => status.stream);
      when(mesh.getRelayStatus).thenAnswer((_) => relay.stream);
      when(identity.getIdentity).thenAnswer((_) async => me);
    });

    blocTest<PeersBloc, PeersState>(
      'When created, loads the identity and follows the streams',
      build: () =>
          PeersBloc(meshRepository: mesh, identityRepository: identity),
      act: (_) async {
        await Future<void>.delayed(Duration.zero);
        peers.add([peer]);
        status.add(
          const MeshStatus(
            phase: MeshPhase.running,
            peerCount: 1,
            nearbyDeviceCount: 2,
          ),
        );
        relay.add(RelayStatus.connected);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const PeersState(identity: me),
        const PeersState(identity: me, peers: [peer]),
        isA<PeersState>().having(
          (s) => s.meshStatus.phase,
          'phase',
          MeshPhase.running,
        ),
        isA<PeersState>().having(
          (s) => s.relayStatus,
          'relay',
          RelayStatus.connected,
        ),
      ],
    );

    blocTest<PeersBloc, PeersState>(
      'When the identity cannot load, the rest still works',
      setUp: () => when(
        identity.getIdentity,
      ).thenAnswer((_) async => throw IdentityLoadException()),
      build: () =>
          PeersBloc(meshRepository: mesh, identityRepository: identity),
      act: (_) async {
        peers.add([peer]);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const PeersState(peers: [peer]),
      ],
    );
  });
}
