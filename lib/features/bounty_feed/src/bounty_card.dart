import 'package:flutter/material.dart';
import 'package:radius/component_library/component_library.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/l10n.dart';

/// One bounty on the board. Feature-local until a second feature wants it.
class BountyCard extends StatelessWidget {
  const BountyCard({
    required this.bounty,
    required this.now,
    required this.onTap,
    this.myClaim,
    super.key,
  });

  final Bounty bounty;
  final DateTime now;
  final VoidCallback onTap;

  /// Where my offer on this bounty stands, when I made one.
  final ClaimStatus? myClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = AppTheme.of(context);
    return ContraCard(
      tone: _toneFor(bounty.status),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContraAvatar(label: bounty.authorLabel),
              const SizedBox(width: Spacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bounty.title,
                      style: theme.bodyStrongTextStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      bounty.isMine
                          ? l10n.bountyFeedAuthorYou
                          : bounty.authorLabel,
                      style: theme.captionTextStyle.copyWith(
                        color: theme.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.small),
              ContraAmountBadge(cents: bounty.amountCents, symbol: '€'),
            ],
          ),
          if (bounty.details.isNotEmpty) ...[
            const SizedBox(height: Spacing.small),
            Text(
              bounty.details,
              style: theme.smallTextStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: Spacing.medium),
          Row(
            children: [
              ContraBadge(
                label: _statusLabel(l10n, bounty.status),
                tone: _toneFor(bounty.status),
              ),
              if (bounty.isPosterAwayAt(now)) ...[
                const SizedBox(width: Spacing.small),
                ContraBadge(
                  label: l10n.bountyFeedPosterAway,
                  tone: Tone.warning,
                ),
              ] else if (bounty.viaInternet) ...[
                const SizedBox(width: Spacing.small),
                ContraBadge(
                  label: l10n.bountyFeedViaInternet,
                  tone: Tone.accent,
                ),
              ],
              if (myClaim != null) ...[
                const SizedBox(width: Spacing.small),
                ContraBadge(
                  label: _claimLabel(l10n, myClaim!),
                  tone: _claimTone(myClaim!),
                  filled: true,
                ),
              ],
              const SizedBox(width: Spacing.small),
              Text(
                _timeLeft(l10n, bounty.expiresAt.difference(now)),
                style: theme.captionTextStyle.copyWith(color: theme.mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Tone _toneFor(BountyStatus status) => switch (status) {
    BountyStatus.open => Tone.neutral,
    BountyStatus.claimed => Tone.accent,
    BountyStatus.done => Tone.success,
    BountyStatus.paid => Tone.success,
    BountyStatus.cancelled => Tone.danger,
  };

  static String _statusLabel(AppLocalizations l10n, BountyStatus status) =>
      switch (status) {
        BountyStatus.open => l10n.bountyFeedStatusOpen,
        BountyStatus.claimed => l10n.bountyFeedStatusClaimed,
        BountyStatus.done => l10n.bountyFeedStatusDone,
        BountyStatus.paid => l10n.bountyFeedStatusPaid,
        BountyStatus.cancelled => l10n.bountyFeedStatusCancelled,
      };

  static String _claimLabel(AppLocalizations l10n, ClaimStatus status) =>
      switch (status) {
        ClaimStatus.pending => l10n.bountyFeedMyClaimPending,
        ClaimStatus.accepted => l10n.bountyFeedMyClaimAccepted,
        ClaimStatus.declined => l10n.bountyFeedMyClaimDeclined,
        ClaimStatus.done => l10n.bountyFeedMyClaimDone,
      };

  static Tone _claimTone(ClaimStatus status) => switch (status) {
    ClaimStatus.pending => Tone.warning,
    ClaimStatus.accepted || ClaimStatus.done => Tone.success,
    ClaimStatus.declined => Tone.danger,
  };

  static String _timeLeft(AppLocalizations l10n, Duration left) {
    if (left.isNegative || left == Duration.zero) {
      return l10n.bountyFeedExpired;
    }
    if (left.inDays >= 1) return l10n.bountyFeedTimeLeftDays(left.inDays);
    if (left.inHours >= 1) return l10n.bountyFeedTimeLeftHours(left.inHours);
    return l10n.bountyFeedTimeLeftMinutes(left.inMinutes.clamp(1, 59));
  }
}
