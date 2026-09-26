import 'dart:typed_data';

import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';

extension BountyRMToCache on BountyRM {
  /// [record] is the exact bytes that arrived or were sent, kept so the
  /// record can be forwarded without re-signing.
  BountyCM toCacheModel({
    required Uint8List record,
    bool viaInternet = false,
  }) => BountyCM(
    id: id,
    authorPeerId: authorPeerId,
    authorSigningKey: authorSigningKey,
    record: record,
    title: title,
    details: details,
    amountCents: amountCents,
    createdAt: createdAt,
    expiresAt: expiresAt,
    updatedAt: updatedAt,
    status: status,
    claimantPeerId: claimantPeerId,
    geohash: geohash,
    viaInternet: viaInternet,
  );
}

extension BountyMessageRMToCache on BountyMessageRM {
  /// A claim message from [from] becomes a pending claim by them.
  ClaimCM toClaimCacheModel({required String from}) => ClaimCM(
    bountyId: bountyId,
    claimantPeerId: from,
    note: note,
    sentAt: sentAt,
    status: ClaimCM.statusPending,
  );
}
