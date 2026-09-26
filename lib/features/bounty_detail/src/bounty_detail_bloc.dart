import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';

part 'bounty_detail_event.dart';
part 'bounty_detail_state.dart';

/// One bounty, and everything a person can do to it from where they stand:
/// claim it, or as its author pick somebody, confirm the work, say it was
/// paid, or withdraw it.
///
/// A Bloc because it follows the bounty and its claims live off two
/// repository streams; a claim arriving while the author is looking at the
/// screen has to show up without a refresh.
class BountyDetailBloc extends Bloc<BountyDetailEvent, BountyDetailState> {
  BountyDetailBloc({
    required this.bountyId,
    required BountyRepository bountyRepository,
  }) : _repository = bountyRepository,
       super(const BountyDetailInProgress()) {
    on<BountyDetailBountyUpdated>(_onBountyUpdated);
    on<BountyDetailClaimsUpdated>(_onClaimsUpdated);
    on<BountyDetailClaimRequested>(
      (e, emit) => _act(emit, () => _repository.claim(bountyId, note: e.note)),
    );
    on<BountyDetailAcceptRequested>(
      (e, emit) => _act(emit, () => _repository.accept(bountyId, e.claimantId)),
    );
    on<BountyDetailDeclineRequested>(
      (e, emit) =>
          _act(emit, () => _repository.decline(bountyId, e.claimantId)),
    );
    on<BountyDetailDoneRequested>(
      (_, emit) => _act(emit, () => _repository.markDone(bountyId)),
    );
    on<BountyDetailPaidRequested>(
      (_, emit) => _act(emit, () => _repository.markPaid(bountyId)),
    );
    on<BountyDetailCancelRequested>(
      (_, emit) => _act(emit, () => _repository.cancel(bountyId)),
    );
    on<BountyDetailErrorShown>((_, emit) {
      final s = state;
      if (s is BountyDetailSuccess) {
        emit(s.copyWith(actionStatus: ActionStatus.idle));
      }
    });

    _subs = [
      bountyRepository.getBounties().listen(
        (list) => add(
          BountyDetailBountyUpdated(
            list.where((b) => b.id == bountyId).firstOrNull,
          ),
        ),
      ),
      bountyRepository.getClaims().listen(
        (list) => add(
          BountyDetailClaimsUpdated(
            list.where((c) => c.bountyId == bountyId).toList(),
          ),
        ),
      ),
    ];
  }

  final String bountyId;
  final BountyRepository _repository;
  late final List<StreamSubscription<Object?>> _subs;
  List<Claim> _claims = const [];

  void _onBountyUpdated(
    BountyDetailBountyUpdated event,
    Emitter<BountyDetailState> emit,
  ) {
    final bounty = event.bounty;
    if (bounty == null) {
      emit(const BountyDetailFailure());
      return;
    }
    final current = state;
    emit(
      BountyDetailSuccess(
        bounty: bounty,
        claims: _claims,
        actionStatus: current is BountyDetailSuccess
            ? current.actionStatus
            : ActionStatus.idle,
      ),
    );
  }

  void _onClaimsUpdated(
    BountyDetailClaimsUpdated event,
    Emitter<BountyDetailState> emit,
  ) {
    _claims = event.claims;
    final current = state;
    if (current is BountyDetailSuccess) {
      emit(current.copyWith(claims: _claims));
    }
  }

  Future<void> _act(
    Emitter<BountyDetailState> emit,
    Future<void> Function() action,
  ) async {
    final current = state;
    if (current is! BountyDetailSuccess) return;
    if (current.actionStatus == ActionStatus.inProgress) return;
    emit(current.copyWith(actionStatus: ActionStatus.inProgress));
    ActionStatus outcome;
    try {
      await action();
      outcome = ActionStatus.idle;
    } on BountyClosedException {
      outcome = ActionStatus.closedError;
    } on MeshNotRunningException {
      outcome = ActionStatus.meshNotRunningError;
    } on BountySendException {
      outcome = ActionStatus.sendError;
    } on BountyCacheException {
      outcome = ActionStatus.cacheError;
    } on BountyValidationException {
      outcome = ActionStatus.validationError;
    } catch (_) {
      outcome = ActionStatus.genericError;
    }
    // The stream may have moved the state on while the action ran, so apply
    // the outcome to whatever is current rather than to what was.
    final latest = state;
    if (latest is BountyDetailSuccess) {
      emit(latest.copyWith(actionStatus: outcome));
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
