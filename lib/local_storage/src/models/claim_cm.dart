/// One person's offer to do one bounty, keyed by both ids.
class ClaimCM {
  const ClaimCM({
    required this.bountyId,
    required this.claimantPeerId,
    required this.note,
    required this.sentAt,
    required this.status,
    this.receivedAt,
  });

  static const statusPending = 1;
  static const statusAccepted = 2;
  static const statusDeclined = 3;
  static const statusDone = 4;

  static String keyFor(String bountyId, String claimantPeerId) =>
      '$bountyId:$claimantPeerId';

  final String bountyId;
  final String claimantPeerId;
  final String note;

  /// Unix seconds.
  final int sentAt;
  final int status;

  /// When the poster's phone said it had the claim, or null while it has
  /// not. Only meaningful on the claimant's side.
  final int? receivedAt;

  String get key => keyFor(bountyId, claimantPeerId);
}
