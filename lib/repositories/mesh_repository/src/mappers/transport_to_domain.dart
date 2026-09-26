import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';

extension MeshLinkToPeers on MeshLink {
  /// Every peer we can address, sorted by id so two snapshots with the same
  /// peers compare equal.
  List<Peer> toPeers() {
    final sessions = sessionPeers.toSet();
    return [
      for (final id in addressablePeers)
        Peer(
          id: id,
          label: MeshLink.labelOf(id),
          hasSecureSession: sessions.contains(id),
          reachableOnMesh: reachableOnMesh(id),
          reachableViaInternet: nostrAddressFor(id) != null,
        ),
    ];
  }
}

extension MeshLinkToStatus on MeshLink {
  MeshStatus toMeshStatus() => MeshStatus(
    phase: _phase,
    peerCount: addressablePeers.length,
    nearbyDeviceCount: observed.length,
  );

  MeshPhase get _phase {
    if (running) return MeshPhase.running;
    if (!wantRunning) return MeshPhase.stopped;
    return switch (state) {
      BluetoothLowEnergyState.unsupported => MeshPhase.unsupported,
      BluetoothLowEnergyState.unauthorized => MeshPhase.unauthorized,
      _ => MeshPhase.waitingForBluetooth,
    };
  }
}

extension RelayConnectionToDomain on bool {
  RelayStatus toRelayStatus() =>
      this ? RelayStatus.connected : RelayStatus.connecting;
}
