import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:radius/repositories/mesh_repository/src/mappers/mappers.dart';

class _MockMeshLink extends Mock implements MeshLink {}

void main() {
  late _MockMeshLink link;

  setUp(() {
    link = _MockMeshLink();
    when(() => link.addressablePeers).thenReturn(const []);
    when(() => link.sessionPeers).thenReturn(const []);
    when(() => link.observed).thenReturn(const []);
    when(() => link.running).thenReturn(false);
    when(() => link.wantRunning).thenReturn(false);
    when(() => link.state).thenReturn(BluetoothLowEnergyState.poweredOn);
  });

  group('peers', () {
    test('flags come from the session, the radio and the address book', () {
      const a = '00112233aabbccdd';
      const b = 'ffeeddcc00112233';
      when(() => link.addressablePeers).thenReturn([a, b]);
      when(() => link.sessionPeers).thenReturn([a]);
      when(() => link.reachableOnMesh(a)).thenReturn(true);
      when(() => link.reachableOnMesh(b)).thenReturn(false);
      when(() => link.nostrAddressFor(a)).thenReturn(null);
      when(() => link.nostrAddressFor(b)).thenReturn('ab' * 32);

      final peers = link.toPeers();

      expect(peers, hasLength(2));
      expect(peers[0].id, a);
      expect(peers[0].label, MeshLink.labelOf(a));
      expect(peers[0].hasSecureSession, isTrue);
      expect(peers[0].reachableOnMesh, isTrue);
      expect(peers[0].reachableViaInternet, isFalse);
      expect(peers[1].hasSecureSession, isFalse);
      expect(peers[1].reachableOnMesh, isFalse);
      expect(peers[1].reachableViaInternet, isTrue);
    });
  });

  group('status', () {
    test('not asked to run is stopped', () {
      expect(link.toMeshStatus(), MeshStatus.stopped);
    });

    test('asked to run with the radio off is waiting', () {
      when(() => link.wantRunning).thenReturn(true);
      when(() => link.state).thenReturn(BluetoothLowEnergyState.poweredOff);
      expect(link.toMeshStatus().phase, MeshPhase.waitingForBluetooth);
    });

    test('permission refused and no radio are told apart', () {
      when(() => link.wantRunning).thenReturn(true);
      when(() => link.state).thenReturn(BluetoothLowEnergyState.unauthorized);
      expect(link.toMeshStatus().phase, MeshPhase.unauthorized);
      when(() => link.state).thenReturn(BluetoothLowEnergyState.unsupported);
      expect(link.toMeshStatus().phase, MeshPhase.unsupported);
    });

    test('running carries the counts', () {
      when(() => link.running).thenReturn(true);
      when(() => link.wantRunning).thenReturn(true);
      when(() => link.addressablePeers).thenReturn(['a', 'b', 'c']);
      when(() => link.observed).thenReturn([
        ObservedPeer(key: 'k1', name: null, rssi: -60),
        ObservedPeer(key: 'k2', name: null, rssi: -70),
      ]);

      expect(
        link.toMeshStatus(),
        const MeshStatus(
          phase: MeshPhase.running,
          peerCount: 3,
          nearbyDeviceCount: 2,
        ),
      );
    });
  });

  test('relay up and down', () {
    expect(true.toRelayStatus(), RelayStatus.connected);
    expect(false.toRelayStatus(), RelayStatus.connecting);
  });
}
