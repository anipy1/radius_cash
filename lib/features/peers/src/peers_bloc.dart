import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

part 'peers_event.dart';
part 'peers_state.dart';

/// The mesh made visible: who this phone can reach, and how.
///
/// A Bloc because it lives off the mesh repository's streams; the list has
/// to move as phones come and go.
class PeersBloc extends Bloc<PeersEvent, PeersState> {
  PeersBloc({
    required MeshRepository meshRepository,
    required IdentityRepository identityRepository,
  }) : super(const PeersState()) {
    on<PeersUpdated>((e, emit) => emit(state.copyWith(peers: e.peers)));
    on<PeersMeshStatusUpdated>(
      (e, emit) => emit(state.copyWith(meshStatus: e.status)),
    );
    on<PeersRelayStatusUpdated>(
      (e, emit) => emit(state.copyWith(relayStatus: e.status)),
    );
    on<PeersIdentityLoaded>(
      (e, emit) => emit(state.copyWith(identity: e.identity)),
    );

    _subs = [
      meshRepository.getPeers().listen((p) => add(PeersUpdated(p))),
      meshRepository.getMeshStatus().listen(
        (s) => add(PeersMeshStatusUpdated(s)),
      ),
      meshRepository.getRelayStatus().listen(
        (s) => add(PeersRelayStatusUpdated(s)),
      ),
    ];
    identityRepository
        .getIdentity()
        .then((identity) {
          if (!isClosed) add(PeersIdentityLoaded(identity));
        })
        .catchError((Object _) {
          // The screen is about other people; ours is a nicety at the top.
        });
  }

  late final List<StreamSubscription<Object?>> _subs;

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
