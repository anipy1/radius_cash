part of 'bounty_detail_bloc.dart';

enum ActionStatus {
  idle,
  inProgress,
  closedError,
  meshNotRunningError,
  sendError,
  cacheError,
  validationError,
  genericError,
}

sealed class BountyDetailState extends Equatable {
  const BountyDetailState();

  @override
  List<Object?> get props => [];
}

/// Waiting for the first snapshot from the repository.
class BountyDetailInProgress extends BountyDetailState {
  const BountyDetailInProgress();
}

class BountyDetailSuccess extends BountyDetailState {
  const BountyDetailSuccess({
    required this.bounty,
    required this.claims,
    this.actionStatus = ActionStatus.idle,
  });

  final Bounty bounty;

  /// Claims on this bounty. For the author, everyone who asked; for anyone
  /// else, at most their own.
  final List<Claim> claims;
  final ActionStatus actionStatus;

  /// My own claim on somebody else's bounty, if I made one.
  Claim? get myClaim => claims.where((c) => c.isMine).firstOrNull;

  bool get isBusy => actionStatus == ActionStatus.inProgress;

  BountyDetailSuccess copyWith({
    Bounty? bounty,
    List<Claim>? claims,
    ActionStatus? actionStatus,
  }) => BountyDetailSuccess(
    bounty: bounty ?? this.bounty,
    claims: claims ?? this.claims,
    actionStatus: actionStatus ?? this.actionStatus,
  );

  @override
  List<Object?> get props => [bounty, claims, actionStatus];
}

/// The bounty is not known on this device.
class BountyDetailFailure extends BountyDetailState {
  const BountyDetailFailure();
}
