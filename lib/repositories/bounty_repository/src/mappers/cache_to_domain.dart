import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';

DateTime _fromUnix(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

extension BountyStatusCodeToDomain on int {
  /// Throws [FormatException] on a code this build does not know, which the
  /// caller treats as a record to drop.
  BountyStatus toBountyStatus() => switch (this) {
    BountyRM.statusOpen => BountyStatus.open,
    BountyRM.statusClaimed => BountyStatus.claimed,
    BountyRM.statusDone => BountyStatus.done,
    BountyRM.statusPaid => BountyStatus.paid,
    BountyRM.statusCancelled => BountyStatus.cancelled,
    _ => throw FormatException('unknown bounty status $this'),
  };
}

extension ClaimStatusCodeToDomain on int {
  ClaimStatus toClaimStatus() => switch (this) {
    ClaimCM.statusPending => ClaimStatus.pending,
    ClaimCM.statusAccepted => ClaimStatus.accepted,
    ClaimCM.statusDeclined => ClaimStatus.declined,
    ClaimCM.statusDone => ClaimStatus.done,
    _ => throw FormatException('unknown claim status $this'),
  };
}

extension BountyCMToDomain on BountyCM {
  Bounty toDomainModel({required String myPeerId}) => Bounty(
    id: id,
    authorId: authorPeerId,
    authorLabel: MeshLink.labelOf(authorPeerId),
    isMine: authorPeerId == myPeerId,
    title: title,
    details: details,
    amountCents: amountCents,
    createdAt: _fromUnix(createdAt),
    expiresAt: _fromUnix(expiresAt),
    updatedAt: _fromUnix(updatedAt),
    status: status.toBountyStatus(),
    claimantId: claimantPeerId,
    claimantLabel: claimantPeerId == null
        ? null
        : MeshLink.labelOf(claimantPeerId!),
    geohash: Geohash.isValid(geohash) ? Geohash(geohash) : null,
    viaInternet: viaInternet,
  );
}

extension ClaimCMToDomain on ClaimCM {
  Claim toDomainModel({required String myPeerId}) => Claim(
    bountyId: bountyId,
    claimantId: claimantPeerId,
    claimantLabel: MeshLink.labelOf(claimantPeerId),
    note: note,
    sentAt: _fromUnix(sentAt),
    status: status.toClaimStatus(),
    isMine: claimantPeerId == myPeerId,
    delivered: receivedAt != null,
  );
}
