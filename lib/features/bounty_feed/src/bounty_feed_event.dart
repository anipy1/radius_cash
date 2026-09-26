part of 'bounty_feed_bloc.dart';

sealed class BountyFeedEvent extends Equatable {
  const BountyFeedEvent();

  @override
  List<Object?> get props => [];
}

/// The screen appeared. Brings the radio up.
class BountyFeedStarted extends BountyFeedEvent {
  const BountyFeedStarted();
}

/// The user asked to try the radio again after it would not start.
class BountyFeedRetryRequested extends BountyFeedEvent {
  const BountyFeedRetryRequested();
}

class BountyFeedSegmentChanged extends BountyFeedEvent {
  const BountyFeedSegmentChanged(this.segment);

  final BountyFeedSegment segment;

  @override
  List<Object?> get props => [segment];
}

class BountyFeedBountiesUpdated extends BountyFeedEvent {
  const BountyFeedBountiesUpdated(this.bounties);

  final List<Bounty> bounties;

  @override
  List<Object?> get props => [bounties];
}

class BountyFeedClaimsUpdated extends BountyFeedEvent {
  const BountyFeedClaimsUpdated(this.claims);

  final List<Claim> claims;

  @override
  List<Object?> get props => [claims];
}

class BountyFeedMeshStatusUpdated extends BountyFeedEvent {
  const BountyFeedMeshStatusUpdated(this.status);

  final MeshStatus status;

  @override
  List<Object?> get props => [status];
}

class BountyFeedRelayStatusUpdated extends BountyFeedEvent {
  const BountyFeedRelayStatusUpdated(this.status);

  final RelayStatus status;

  @override
  List<Object?> get props => [status];
}

/// The cache underneath the lists broke. Shown, not hidden.
class BountyFeedCacheFailed extends BountyFeedEvent {
  const BountyFeedCacheFailed();
}
