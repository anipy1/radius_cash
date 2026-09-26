import 'package:equatable/equatable.dart';

/// Somebody who was close enough to hear a completion and signed to say so.
///
/// A standalone record, not a field on the bounty. Each one is independently
/// checkable by whoever holds it, which is what makes a pile of them worth
/// more than the claimant's own word.
class Witness extends Equatable {
  const Witness({
    required this.bountyId,
    required this.witnessId,
    required this.witnessLabel,
    required this.claimantId,
    required this.at,
    required this.isMine,
  });

  final String bountyId;

  /// The peer id that signed, proved against its own noise key.
  final String witnessId;

  /// The four characters people read off a screen.
  final String witnessLabel;

  /// Who they are vouching for.
  final String claimantId;

  final DateTime at;

  /// This device signed it.
  final bool isMine;

  @override
  List<Object?> get props => [
    bountyId,
    witnessId,
    witnessLabel,
    claimantId,
    at,
    isMine,
  ];
}
