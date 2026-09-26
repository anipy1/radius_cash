import 'dart:typed_data';

/// One phone's co-signature that it heard a completion, keyed by the bounty
/// and the witness.
///
/// [record] is the exact signed bytes as they arrived. Keeping them means a
/// witness can be forwarded or re-checked by anyone later, which is the point
/// of the record being standalone; rebuilding it from the fields would
/// produce different bytes and a signature that no longer verifies.
class WitnessCM {
  const WitnessCM({
    required this.bountyId,
    required this.claimantPeerId,
    required this.witnessPeerId,
    required this.record,
    required this.at,
    this.mine = false,
  });

  static String keyFor(String bountyId, String witnessPeerId) =>
      '$bountyId:$witnessPeerId';

  final String bountyId;
  final String claimantPeerId;
  final String witnessPeerId;

  /// The 157 signed bytes, verbatim.
  final Uint8List record;

  /// Unix seconds.
  final int at;

  /// This device signed it. What makes "sign at most once per bounty" a
  /// cache lookup rather than a flag somewhere else.
  final bool mine;

  String get key => keyFor(bountyId, witnessPeerId);
}
