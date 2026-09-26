import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/l10n/generated/app_localizations_en.dart';
import 'package:radius/notifications/notifications.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';

class _MockBountyRepository extends Mock implements BountyRepository {}

class _MockIdentityRepository extends Mock implements IdentityRepository {}

class _FakeNotifier implements Notifier {
  final shown = <Alert>[];
  int asked = 0;

  @override
  Future<void> requestPermission() async => asked++;

  @override
  Future<void> show(Alert alert) async => shown.add(alert);

  @override
  Stream<String> get opened => const Stream.empty();

  @override
  Future<String?> launchRoute() async => null;
}

void main() {
  const me = 'me00000000000000';
  const them = 'them000000000000';
  final now = DateTime(2026, 9, 11, 12);

  late _MockBountyRepository bounties;
  late _MockIdentityRepository identity;
  late _FakeNotifier notifier;
  late StreamController<List<Bounty>> bountyStream;
  late StreamController<List<Claim>> claimStream;
  late bool inForeground;
  late BountyNotifier subject;

  Bounty bounty({
    String id = 'b1',
    bool mine = false,
    BountyStatus status = BountyStatus.open,
    String? claimantId,
  }) => Bounty(
    id: id,
    authorId: mine ? me : them,
    authorLabel: mine ? 'ME00' : 'THEM',
    isMine: mine,
    title: 'Water the plants',
    details: '',
    amountCents: 800,
    createdAt: now,
    expiresAt: now.add(const Duration(days: 1)),
    updatedAt: now,
    status: status,
    claimantId: claimantId,
    claimantLabel: claimantId == null ? null : 'CLMT',
  );

  Claim claim({
    String bountyId = 'b1',
    bool mine = false,
    ClaimStatus status = ClaimStatus.pending,
    String note = '',
  }) => Claim(
    bountyId: bountyId,
    claimantId: mine ? me : them,
    claimantLabel: mine ? 'ME00' : 'THEM',
    note: note,
    sentAt: now,
    status: status,
    isMine: mine,
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    bounties = _MockBountyRepository();
    identity = _MockIdentityRepository();
    notifier = _FakeNotifier();
    bountyStream = StreamController<List<Bounty>>();
    claimStream = StreamController<List<Claim>>();
    inForeground = false;
    when(() => bounties.getBounties()).thenAnswer((_) => bountyStream.stream);
    when(() => bounties.getClaims()).thenAnswer((_) => claimStream.stream);
    when(() => identity.hasOnboarded()).thenAnswer((_) async => true);
    when(() => identity.getIdentity()).thenAnswer(
      (_) async => const Identity(
        peerId: me,
        shortId: 'ME00',
        npub: 'npub1me',
        origin: IdentityOrigin.restored,
      ),
    );
    subject = BountyNotifier(
      bountyRepository: bounties,
      identityRepository: identity,
      notifier: notifier,
      strings: AppLocalizationsEn.new,
      isInForeground: () => inForeground,
      formatAmount: (cents) => '€${cents ~/ 100}',
      routeFor: (id) => '/bounties/$id',
      clock: () => now,
    )..start();
  });

  tearDown(() async {
    await subject.dispose();
    await bountyStream.close();
    await claimStream.close();
  });

  test('the first list from each stream is the cache, not news', () async {
    bountyStream.add([bounty()]);
    claimStream.add([claim()]);
    await settle();
    expect(notifier.shown, isEmpty);
  });

  test('a new bounty from somebody else nearby is announced', () async {
    bountyStream.add(const []);
    await settle();
    bountyStream.add([bounty()]);
    await settle();
    expect(notifier.shown, hasLength(1));
    final alert = notifier.shown.single;
    expect(alert.title, 'New bounty nearby: Water the plants');
    expect(alert.body, '€8 from THEM');
    expect(alert.route, '/bounties/b1');
  });

  test('my own post is not news to me', () async {
    bountyStream.add(const []);
    await settle();
    bountyStream.add([bounty(mine: true)]);
    await settle();
    expect(notifier.shown, isEmpty);
  });

  test('a bounty already claimed or expired is not announced', () async {
    bountyStream.add(const []);
    await settle();
    bountyStream.add([
      bounty(id: 'claimed', status: BountyStatus.claimed, claimantId: them),
    ]);
    await settle();
    expect(notifier.shown, isEmpty);
  });

  test('nothing is shown while the app is in the foreground', () async {
    inForeground = true;
    bountyStream.add(const []);
    await settle();
    bountyStream.add([bounty()]);
    await settle();
    expect(notifier.shown, isEmpty);
  });

  test('a claim on my bounty is announced with the note', () async {
    bountyStream.add([bounty(mine: true)]);
    claimStream.add(const []);
    await settle();
    claimStream.add([claim(note: 'I have a watering can')]);
    await settle();
    final alert = notifier.shown.single;
    expect(alert.title, 'THEM wants to do Water the plants');
    expect(alert.body, 'I have a watering can');
  });

  test('my claim being accepted or declined is announced', () async {
    bountyStream.add([bounty()]);
    claimStream.add([claim(mine: true)]);
    await settle();
    claimStream.add([claim(mine: true, status: ClaimStatus.accepted)]);
    await settle();
    expect(notifier.shown.last.title, 'THEM picked you for Water the plants');

    claimStream.add([claim(mine: true, status: ClaimStatus.declined)]);
    await settle();
    expect(
      notifier.shown.last.title,
      'THEM passed on your claim for Water the plants',
    );
    expect(notifier.shown, hasLength(2));
  });

  test('the person doing my bounty saying done is announced', () async {
    bountyStream.add([bounty(mine: true)]);
    claimStream.add([claim(status: ClaimStatus.accepted)]);
    await settle();
    claimStream.add([claim(status: ClaimStatus.done)]);
    await settle();
    expect(notifier.shown.single.title, 'THEM says Water the plants is done');
  });

  test('a bounty I am doing being marked done and paid is announced', () async {
    bountyStream.add([bounty(status: BountyStatus.claimed, claimantId: me)]);
    await settle();
    bountyStream.add([bounty(status: BountyStatus.done, claimantId: me)]);
    await settle();
    expect(notifier.shown.last.title, 'Water the plants is marked done');
    bountyStream.add([bounty(status: BountyStatus.paid, claimantId: me)]);
    await settle();
    expect(notifier.shown.last.title, 'Water the plants is paid');
    expect(notifier.shown.last.body, '€8 from THEM. Nice work.');
  });

  test('a status change on a bounty somebody else is doing is quiet', () async {
    bountyStream.add([bounty(status: BountyStatus.claimed, claimantId: them)]);
    await settle();
    bountyStream.add([bounty(status: BountyStatus.paid, claimantId: them)]);
    await settle();
    expect(notifier.shown, isEmpty);
  });

  test('alerts about one bounty share an id, so they replace', () async {
    bountyStream.add([bounty(status: BountyStatus.claimed, claimantId: me)]);
    await settle();
    bountyStream.add([bounty(status: BountyStatus.done, claimantId: me)]);
    bountyStream.add([bounty(status: BountyStatus.paid, claimantId: me)]);
    await settle();
    expect(notifier.shown.map((a) => a.id).toSet(), hasLength(1));
  });

  test('permission is asked once, and only after onboarding', () async {
    when(() => identity.hasOnboarded()).thenAnswer((_) async => false);
    bountyStream.add(const []);
    await settle();
    bountyStream.add([bounty()]);
    await settle();
    expect(notifier.asked, 0);

    when(() => identity.hasOnboarded()).thenAnswer((_) async => true);
    bountyStream.add([bounty(), bounty(id: 'b2')]);
    await settle();
    bountyStream.add([bounty(), bounty(id: 'b2'), bounty(id: 'b3')]);
    await settle();
    expect(notifier.asked, 1);
  });
}
