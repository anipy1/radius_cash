import 'dart:async';

import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/l10n.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';

import 'notifier.dart';

/// Turns changes on the bounty and claim streams into alerts.
///
/// Watches the same streams the screens do and diffs each list against the
/// last one, so the repositories never learn that a notification tray
/// exists. The first list from each stream is the cache, not news, and is
/// only remembered. Nothing is shown while the app is in the foreground:
/// the screen it would point at is already updating.
class BountyNotifier {
  BountyNotifier({
    required BountyRepository bountyRepository,
    required IdentityRepository identityRepository,
    required Notifier notifier,
    required AppLocalizations Function() strings,
    required bool Function() isInForeground,
    required String Function(int cents) formatAmount,
    required String Function(String bountyId) routeFor,
    DateTime Function()? clock,
  }) : _bounties = bountyRepository,
       _identity = identityRepository,
       _notifier = notifier,
       _strings = strings,
       _isInForeground = isInForeground,
       _formatAmount = formatAmount,
       _routeFor = routeFor,
       _now = clock ?? DateTime.now;

  final BountyRepository _bounties;
  final IdentityRepository _identity;
  final Notifier _notifier;
  final AppLocalizations Function() _strings;
  final bool Function() _isInForeground;
  final String Function(int cents) _formatAmount;
  final String Function(String bountyId) _routeFor;
  final DateTime Function() _now;

  final List<StreamSubscription<Object?>> _subs = [];
  Map<String, Bounty>? _knownBounties;
  Map<String, Claim>? _knownClaims;
  bool _askedPermission = false;

  void start() {
    _subs.add(_bounties.getBounties().listen(_onBounties));
    _subs.add(_bounties.getClaims().listen(_onClaims));
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  Future<void> _onBounties(List<Bounty> list) async {
    final next = {for (final b in list) b.id: b};
    final known = _knownBounties;
    _knownBounties = next;
    if (known == null) return;
    await _askOnce();
    final me = (await _identity.getIdentity()).peerId;
    final s = _strings();
    for (final bounty in list) {
      final before = known[bounty.id];
      if (before == null) {
        final now = _now();
        if (!bounty.isMine &&
            bounty.isClaimableAt(now) &&
            !bounty.isPosterAwayAt(now)) {
          await _show(
            bounty.id,
            s.notificationNewBountyTitle(bounty.title),
            s.notificationNewBountyBody(
              _formatAmount(bounty.amountCents),
              bounty.authorLabel,
            ),
          );
        }
        continue;
      }
      if (before.status == bounty.status) continue;
      // The poster changed a record I am doing.
      if (bounty.claimantId != me || bounty.isMine) continue;
      if (bounty.status == BountyStatus.done) {
        await _show(
          bounty.id,
          s.notificationBountyDoneTitle(bounty.title),
          s.notificationBountyDoneBody(bounty.authorLabel),
        );
      } else if (bounty.status == BountyStatus.paid) {
        await _show(
          bounty.id,
          s.notificationBountyPaidTitle(bounty.title),
          s.notificationBountyPaidBody(
            _formatAmount(bounty.amountCents),
            bounty.authorLabel,
          ),
        );
      }
    }
  }

  Future<void> _onClaims(List<Claim> list) async {
    final next = {for (final c in list) _claimKey(c): c};
    final known = _knownClaims;
    _knownClaims = next;
    if (known == null) return;
    await _askOnce();
    final s = _strings();
    for (final claim in list) {
      final before = known[_claimKey(claim)];
      final title = _knownBounties?[claim.bountyId]?.title ?? '';
      if (before == null) {
        // Somebody offering to do one of mine.
        if (!claim.isMine && claim.status == ClaimStatus.pending) {
          await _show(
            claim.bountyId,
            s.notificationClaimReceivedTitle(claim.claimantLabel, title),
            claim.note.isEmpty
                ? s.notificationClaimReceivedBodyEmpty
                : claim.note,
          );
        }
        continue;
      }
      if (before.status == claim.status) continue;
      if (claim.isMine) {
        // The poster answered me.
        final poster = _knownBounties?[claim.bountyId]?.authorLabel ?? '';
        if (claim.status == ClaimStatus.accepted) {
          await _show(
            claim.bountyId,
            s.notificationClaimAcceptedTitle(poster, title),
            s.notificationClaimAcceptedBody,
          );
        } else if (claim.status == ClaimStatus.declined) {
          await _show(
            claim.bountyId,
            s.notificationClaimDeclinedTitle(poster, title),
            s.notificationClaimDeclinedBody,
          );
        }
      } else if (claim.status == ClaimStatus.done) {
        // The person doing mine says it is finished.
        await _show(
          claim.bountyId,
          s.notificationClaimantDoneTitle(claim.claimantLabel, title),
          s.notificationClaimantDoneBody,
        );
      }
    }
  }

  /// Asked the first time there is news and the user has been through
  /// onboarding, so the question arrives with a reason attached rather
  /// than as the first thing a new user sees.
  Future<void> _askOnce() async {
    if (_askedPermission) return;
    if (!await _identity.hasOnboarded()) return;
    _askedPermission = true;
    await _notifier.requestPermission();
  }

  Future<void> _show(String bountyId, String title, String body) async {
    if (_isInForeground()) return;
    await _notifier.show(
      Alert(
        id: bountyId.hashCode & 0x7fffffff,
        title: title,
        body: body,
        route: _routeFor(bountyId),
      ),
    );
  }

  static String _claimKey(Claim c) => '${c.bountyId}:${c.claimantId}';
}
