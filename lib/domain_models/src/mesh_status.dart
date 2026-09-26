import 'package:equatable/equatable.dart';

enum MeshPhase {
  /// Not asked to run.
  stopped,

  /// Asked to run, waiting for the Bluetooth radio to be switched on.
  waitingForBluetooth,

  /// The user has not granted Bluetooth permission.
  unauthorized,

  /// This device has no usable Bluetooth LE.
  unsupported,

  running,
}

class MeshStatus extends Equatable {
  const MeshStatus({
    required this.phase,
    required this.peerCount,
    required this.nearbyDeviceCount,
  });

  static const stopped = MeshStatus(
    phase: MeshPhase.stopped,
    peerCount: 0,
    nearbyDeviceCount: 0,
  );

  final MeshPhase phase;

  /// Peers we can address by id.
  final int peerCount;

  /// Radios seen advertising in the last half minute, addressable or not.
  final int nearbyDeviceCount;

  @override
  List<Object?> get props => [phase, peerCount, nearbyDeviceCount];
}
