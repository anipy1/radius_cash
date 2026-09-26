import 'dart:typed_data';

/// A bounty as cached. Carries the signed wire bytes as well as the decoded
/// fields, because gossip forwards other people's records verbatim and we
/// cannot re-sign them.
class BountyCM {
  const BountyCM({
    required this.id,
    required this.authorPeerId,
    required this.authorSigningKey,
    required this.record,
    required this.title,
    required this.details,
    required this.amountCents,
    required this.createdAt,
    required this.expiresAt,
    required this.updatedAt,
    required this.status,
    required this.claimantPeerId,
    this.geohash = '',
    this.viaInternet = false,
  });

  final String id;
  final String authorPeerId;
  final Uint8List authorSigningKey;
  final Uint8List record;
  final String title;
  final String details;
  final int amountCents;

  /// Unix seconds, as on the wire.
  final int createdAt;
  final int expiresAt;
  final int updatedAt;

  /// The wire code, 1 to 5.
  final int status;
  final String? claimantPeerId;

  /// Coarse cell from the record, or empty.
  final String geohash;

  /// True until the same record is heard on the radio.
  final bool viaInternet;
}
