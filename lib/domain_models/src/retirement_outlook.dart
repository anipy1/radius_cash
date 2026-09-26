import 'package:equatable/equatable.dart';

/// What forgetting the identity would leave behind, worked out before
/// anything is erased, so the person can decide with the facts.
class RetirementOutlook extends Equatable {
  const RetirementOutlook({
    required this.openBountyTitles,
    required this.pendingClaimCount,
    required this.canAnnounce,
  });

  /// My bounties still open or claimed, by title.
  final List<String> openBountyTitles;

  /// My claims the poster has not closed.
  final int pendingClaimCount;

  /// Whether a cancellation could reach anyone right now, by radio or
  /// internet. When false, everything above stays as it is under the old
  /// name until it expires.
  final bool canAnnounce;

  bool get leavesSomethingBehind =>
      openBountyTitles.isNotEmpty || pendingClaimCount > 0;

  @override
  List<Object?> get props => [openBountyTitles, pendingClaimCount, canAnnounce];
}
