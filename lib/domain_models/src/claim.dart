import 'package:equatable/equatable.dart';

enum ClaimStatus {
  /// Sent, no answer yet.
  pending,
  accepted,
  declined,

  /// The claimant says they finished.
  done,
}

/// Somebody offering to do a bounty. Private between them and the author.
class Claim extends Equatable {
  const Claim({
    required this.bountyId,
    required this.claimantId,
    required this.claimantLabel,
    required this.note,
    required this.sentAt,
    required this.status,
    required this.isMine,
    this.delivered = false,
  });

  final String bountyId;
  final String claimantId;
  final String claimantLabel;
  final String note;
  final DateTime sentAt;
  final ClaimStatus status;

  /// This device is the claimant, as opposed to the author receiving it.
  final bool isMine;

  /// The poster's phone confirmed it has this claim. Says nothing about
  /// what the poster thinks of it.
  final bool delivered;

  @override
  List<Object?> get props => [
    bountyId,
    claimantId,
    claimantLabel,
    note,
    sentAt,
    status,
    isMine,
    delivered,
  ];
}
