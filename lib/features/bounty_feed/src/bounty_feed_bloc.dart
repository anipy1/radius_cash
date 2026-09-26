import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/location_repository/location_repository.dart';
import 'package:radius/repositories/mesh_repository/mesh_repository.dart';

part 'bounty_feed_event.dart';
part 'bounty_feed_state.dart';

/// The home screen's brain: what is on the notice board, who is in range,
/// and whether the radio is up.
///
/// A Bloc rather than a Cubit because it lives off four repository streams,
/// and funnelling those into events is the one thing the kit reserves a Bloc
/// for. It also owns bringing the mesh up, since this is the first screen a
/// user sees and the radio has to be running before anything else is useful.
class BountyFeedBloc extends Bloc<BountyFeedEvent, BountyFeedState> {
  BountyFeedBloc({
    required BountyRepository bountyRepository,
    required MeshRepository meshRepository,
    required LocationRepository locationRepository,
  }) : _bountyRepository = bountyRepository,
       _meshRepository = meshRepository,
       _locationRepository = locationRepository,
       super(const BountyFeedState()) {
    on<BountyFeedStarted>(_onStarted);
    on<BountyFeedRetryRequested>(_onStarted);
    on<BountyFeedSegmentChanged>(
      (event, emit) => emit(state.copyWith(segment: event.segment)),
    );
    on<BountyFeedBountiesUpdated>(
      (event, emit) => emit(state.copyWith(bounties: event.bounties)),
    );
    on<BountyFeedClaimsUpdated>(
      (event, emit) => emit(state.copyWith(claims: event.claims)),
    );
    on<BountyFeedMeshStatusUpdated>(
      (event, emit) => emit(state.copyWith(meshStatus: event.status)),
    );
    on<BountyFeedRelayStatusUpdated>(
      (event, emit) => emit(state.copyWith(relayStatus: event.status)),
    );
    on<BountyFeedCacheFailed>(
      (event, emit) => emit(state.copyWith(cacheFailed: true)),
    );

    _subs = [
      bountyRepository.getBounties().listen(
        (b) => add(BountyFeedBountiesUpdated(b)),
      ),
      bountyRepository.getClaims().listen(
        (c) => add(BountyFeedClaimsUpdated(c)),
      ),
      bountyRepository.cacheFailures.listen(
        (_) => add(const BountyFeedCacheFailed()),
      ),
      meshRepository.getMeshStatus().listen(
        (s) => add(BountyFeedMeshStatusUpdated(s)),
      ),
      meshRepository.getRelayStatus().listen(
        (s) => add(BountyFeedRelayStatusUpdated(s)),
      ),
    ];
  }

  final BountyRepository _bountyRepository;
  final MeshRepository _meshRepository;
  final LocationRepository _locationRepository;
  late final List<StreamSubscription<Object?>> _subs;

  Future<void> _onStarted(
    BountyFeedEvent event,
    Emitter<BountyFeedState> emit,
  ) async {
    emit(state.copyWith(startStatus: MeshStartStatus.starting));
    try {
      await _meshRepository.start();
      emit(state.copyWith(startStatus: MeshStartStatus.started));
    } on MeshUnavailableException {
      emit(state.copyWith(startStatus: MeshStartStatus.failed));
      return;
    } on IdentityLoadException {
      emit(state.copyWith(startStatus: MeshStartStatus.failed));
      return;
    }
    // The internet is a bonus. A relay that cannot be reached costs a badge
    // and nothing else, so its failure is not the screen's failure.
    try {
      await _meshRepository.startRelays();
    } on RelayUnavailableException {
      // Shown as "offline" by the relay status stream already.
    }
    // Where we are, coarsely, so listings from further than a radio reaches
    // can show. Saying no to location costs exactly that and nothing else.
    try {
      final area = await _locationRepository.currentGeohash();
      await _bountyRepository.followArea(area);
    } on LocationPermissionDeniedException {
      // Radio only.
    } on LocationUnavailableException {
      // Radio only.
    }
  }

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
