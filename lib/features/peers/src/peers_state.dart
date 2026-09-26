part of 'peers_bloc.dart';

class PeersState extends Equatable {
  const PeersState({
    this.peers = const [],
    this.meshStatus = MeshStatus.stopped,
    this.relayStatus = RelayStatus.stopped,
    this.identity,
  });

  final List<Peer> peers;
  final MeshStatus meshStatus;
  final RelayStatus relayStatus;

  /// Null until loaded.
  final Identity? identity;

  PeersState copyWith({
    List<Peer>? peers,
    MeshStatus? meshStatus,
    RelayStatus? relayStatus,
    Identity? identity,
  }) => PeersState(
    peers: peers ?? this.peers,
    meshStatus: meshStatus ?? this.meshStatus,
    relayStatus: relayStatus ?? this.relayStatus,
    identity: identity ?? this.identity,
  );

  @override
  List<Object?> get props => [peers, meshStatus, relayStatus, identity];
}
