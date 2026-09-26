part of 'bounty_detail_bloc.dart';

sealed class BountyDetailEvent extends Equatable {
  const BountyDetailEvent();

  @override
  List<Object?> get props => [];
}

class BountyDetailBountyUpdated extends BountyDetailEvent {
  const BountyDetailBountyUpdated(this.bounty);

  /// Null when the bounty is not known here (any more).
  final Bounty? bounty;

  @override
  List<Object?> get props => [bounty];
}

class BountyDetailClaimsUpdated extends BountyDetailEvent {
  const BountyDetailClaimsUpdated(this.claims);

  final List<Claim> claims;

  @override
  List<Object?> get props => [claims];
}

class BountyDetailClaimRequested extends BountyDetailEvent {
  const BountyDetailClaimRequested({this.note = ''});

  final String note;

  @override
  List<Object?> get props => [note];
}

class BountyDetailAcceptRequested extends BountyDetailEvent {
  const BountyDetailAcceptRequested(this.claimantId);

  final String claimantId;

  @override
  List<Object?> get props => [claimantId];
}

class BountyDetailDeclineRequested extends BountyDetailEvent {
  const BountyDetailDeclineRequested(this.claimantId);

  final String claimantId;

  @override
  List<Object?> get props => [claimantId];
}

class BountyDetailDoneRequested extends BountyDetailEvent {
  const BountyDetailDoneRequested();
}

class BountyDetailPaidRequested extends BountyDetailEvent {
  const BountyDetailPaidRequested();
}

class BountyDetailCancelRequested extends BountyDetailEvent {
  const BountyDetailCancelRequested();
}

class BountyDetailErrorShown extends BountyDetailEvent {
  const BountyDetailErrorShown();
}
