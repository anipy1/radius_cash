import 'package:flutter_test/flutter_test.dart';
import 'package:radius/domain_models/domain_models.dart';

void main() {
  final deadline = DateTime.utc(2026, 9, 26, 12);
  final bounty = Bounty(
    id: 'a',
    authorId: 'b',
    authorLabel: 'BBBB',
    isMine: false,
    title: 't',
    details: '',
    amountCents: 100,
    createdAt: deadline.subtract(const Duration(hours: 1)),
    expiresAt: deadline,
    updatedAt: deadline.subtract(const Duration(hours: 1)),
    status: BountyStatus.open,
    claimantId: null,
    claimantLabel: null,
  );

  test('expiry is inclusive of the deadline', () {
    expect(
      bounty.isExpiredAt(deadline.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    expect(bounty.isExpiredAt(deadline), isTrue);
    expect(bounty.isExpiredAt(deadline.add(const Duration(days: 1))), isTrue);
  });

  test('claimable means open and not expired', () {
    final before = deadline.subtract(const Duration(minutes: 5));
    expect(bounty.isClaimableAt(before), isTrue);
    expect(bounty.isClaimableAt(deadline), isFalse);
  });

  group('poster liveness', () {
    final heard = deadline.subtract(const Duration(hours: 1));
    Bounty at({bool mine = false, BountyStatus status = BountyStatus.open}) =>
        Bounty(
          id: 'a',
          authorId: 'b',
          authorLabel: 'BBBB',
          isMine: mine,
          title: 't',
          details: '',
          amountCents: 100,
          createdAt: heard,
          expiresAt: deadline,
          updatedAt: heard,
          status: status,
          claimantId: null,
          claimantLabel: null,
        );

    test('a poster is away after a lease without a renewal', () {
      final b = at();
      expect(b.isPosterAwayAt(heard.add(const Duration(minutes: 9))), isFalse);
      expect(b.isPosterAwayAt(heard.add(Bounty.posterLease)), isTrue);
    });

    test('and lapsed after two', () {
      final b = at();
      expect(b.isLapsedAt(heard.add(const Duration(minutes: 19))), isFalse);
      expect(b.isLapsedAt(heard.add(Bounty.posterLapse)), isTrue);
    });

    test('my own bounties are never away, whatever the clock says', () {
      final b = at(mine: true);
      final later = heard.add(const Duration(hours: 5));
      expect(b.isPosterAwayAt(later), isFalse);
      expect(b.isLapsedAt(later), isFalse);
    });

    test('only open bounties count; a claimed one has a claimant to ask', () {
      final b = at(status: BountyStatus.claimed);
      expect(b.isPosterAwayAt(heard.add(const Duration(hours: 5))), isFalse);
    });
  });
}
