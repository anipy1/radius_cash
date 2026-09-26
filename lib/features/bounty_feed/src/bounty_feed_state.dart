part of 'bounty_feed_bloc.dart';

enum BountyFeedSegment { nearby, mine, claimed }

enum MeshStartStatus { starting, started, failed }

class BountyFeedState extends Equatable {
  const BountyFeedState({
    this.segment = BountyFeedSegment.nearby,
    this.bounties = const [],
    this.claims = const [],
    this.meshStatus = MeshStatus.stopped,
    this.relayStatus = RelayStatus.stopped,
    this.startStatus = MeshStartStatus.starting,
    this.cacheFailed = false,
  });

  final BountyFeedSegment segment;

  /// Everything the repository shows: other people's open bounties plus my
  /// own and the ones I claimed, whatever their state.
  final List<Bounty> bounties;
  final List<Claim> claims;
  final MeshStatus meshStatus;
  final RelayStatus relayStatus;
  final MeshStartStatus startStatus;
  final bool cacheFailed;

  /// What the chosen segment shows.
  List<Bounty> get visible {
    switch (segment) {
      case BountyFeedSegment.nearby:
        return bounties
            .where((b) => !b.isMine && b.status == BountyStatus.open)
            .toList();
      case BountyFeedSegment.mine:
        return bounties.where((b) => b.isMine).toList();
      case BountyFeedSegment.claimed:
        final claimed = {
          for (final c in claims)
            if (c.isMine) c.bountyId,
        };
        return bounties.where((b) => claimed.contains(b.id)).toList();
    }
  }

  BountyFeedState copyWith({
    BountyFeedSegment? segment,
    List<Bounty>? bounties,
    List<Claim>? claims,
    MeshStatus? meshStatus,
    RelayStatus? relayStatus,
    MeshStartStatus? startStatus,
    bool? cacheFailed,
  }) => BountyFeedState(
    segment: segment ?? this.segment,
    bounties: bounties ?? this.bounties,
    claims: claims ?? this.claims,
    meshStatus: meshStatus ?? this.meshStatus,
    relayStatus: relayStatus ?? this.relayStatus,
    startStatus: startStatus ?? this.startStatus,
    cacheFailed: cacheFailed ?? this.cacheFailed,
  );

  @override
  List<Object?> get props => [
    segment,
    bounties,
    claims,
    meshStatus,
    relayStatus,
    startStatus,
    cacheFailed,
  ];
}
