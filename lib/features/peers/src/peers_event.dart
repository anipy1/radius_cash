part of 'peers_bloc.dart';

sealed class PeersEvent extends Equatable {
  const PeersEvent();

  @override
  List<Object?> get props => [];
}

class PeersUpdated extends PeersEvent {
  const PeersUpdated(this.peers);

  final List<Peer> peers;

  @override
  List<Object?> get props => [peers];
}

class PeersMeshStatusUpdated extends PeersEvent {
  const PeersMeshStatusUpdated(this.status);

  final MeshStatus status;

  @override
  List<Object?> get props => [status];
}

class PeersRelayStatusUpdated extends PeersEvent {
  const PeersRelayStatusUpdated(this.status);

  final RelayStatus status;

  @override
  List<Object?> get props => [status];
}

class PeersIdentityLoaded extends PeersEvent {
  const PeersIdentityLoaded(this.identity);

  final Identity identity;

  @override
  List<Object?> get props => [identity];
}
