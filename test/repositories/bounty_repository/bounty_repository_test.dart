import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr/nostr.dart' hide Tags;
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:radius/repositories/bounty_repository/bounty_repository.dart';
import 'package:radius/repositories/bounty_repository/src/bounty_local_storage.dart';

class _MockMeshLink extends Mock implements MeshLink {}

class _FakeRelays implements RelayTransport {
  final incoming = StreamController<Event>.broadcast();
  final published = <Event>[];
  final subscriptions = <List<Filter>>[];
  bool up = true;

  @override
  Stream<Event> get events => incoming.stream;
  @override
  Stream<PublishResult> get results => const Stream.empty();
  @override
  Stream<String> get notices => const Stream.empty();
  @override
  Stream<bool> get connectionChanges => const Stream.empty();
  @override
  bool get isConnected => up;
  @override
  void open() {}
  @override
  void nudge() {}
  @override
  String subscribe(List<Filter> filters, {String? subscriptionId}) {
    subscriptions.add(filters);
    return 'sub${subscriptions.length}';
  }

  @override
  void unsubscribe(String subscriptionId) {}
  @override
  void publish(Event event) => published.add(event);
  @override
  Future<void> close() async {}
}

class _MemoryStorage extends BountyLocalStorage {
  _MemoryStorage()
    : super(keyValueStorage: KeyValueStorage(initialize: (_) async {}));

  final bounties = <String, BountyCM>{};
  final claims = <String, ClaimCM>{};

  @override
  Future<List<BountyCM>> getBounties() async => bounties.values.toList();
  @override
  Future<BountyCM?> getBounty(String id) async => bounties[id];
  @override
  Future<void> upsertBounty(BountyCM bounty) async =>
      bounties[bounty.id] = bounty;
  @override
  Future<List<ClaimCM>> getClaims() async => claims.values.toList();
  @override
  Future<ClaimCM?> getClaim(String bountyId, String claimantPeerId) async =>
      claims[ClaimCM.keyFor(bountyId, claimantPeerId)];
  @override
  Future<void> upsertClaim(ClaimCM claim) async => claims[claim.key] = claim;
  @override
  Future<void> deleteClaim(String bountyId, String claimantPeerId) async =>
      claims.remove(ClaimCM.keyFor(bountyId, claimantPeerId));
  @override
  Future<void> clear() async {
    bounties.clear();
    claims.clear();
  }
}

class _BrokenStorage extends _MemoryStorage {
  @override
  Future<List<BountyCM>> getBounties() => throw BountyCacheException();
  @override
  Future<void> upsertBounty(BountyCM bounty) => throw BountyCacheException();
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  final now = DateTime.utc(2026, 9, 26, 12);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  late NodeIdentity me;
  late NodeIdentity other;
  late NodeIdentity third;
  late _MockMeshLink link;
  late _MemoryStorage storage;
  late StreamController<Uint8List> records;
  late StreamController<({String from, Uint8List body})> messages;
  late StreamController<LogLine> logs;
  late List<Uint8List> published;
  late List<(String, Uint8List)> sent;
  late _FakeRelays relays;

  setUpAll(() async {
    registerFallbackValue(Uint8List(0));
    me = await NodeIdentity.fromSeed(Uint8List.fromList(List.filled(32, 1)));
    other = await NodeIdentity.fromSeed(Uint8List.fromList(List.filled(32, 2)));
    third = await NodeIdentity.fromSeed(Uint8List.fromList(List.filled(32, 3)));
  });

  setUp(() {
    link = _MockMeshLink();
    storage = _MemoryStorage();
    records = StreamController.broadcast();
    messages = StreamController.broadcast();
    logs = StreamController.broadcast();
    published = [];
    sent = [];
    relays = _FakeRelays();
    when(() => link.identity).thenReturn(me);
    when(() => link.running).thenReturn(true);
    when(() => link.addressablePeers).thenReturn(const []);
    when(() => link.neighbours).thenReturn(const {});
    when(() => link.canReach(any())).thenReturn(false);
    when(() => link.bountyRecords).thenAnswer((_) => records.stream);
    when(() => link.bountyMessages).thenAnswer((_) => messages.stream);
    when(() => link.logs).thenAnswer((_) => logs.stream);
    when(() => link.note(any())).thenReturn(null);
    when(() => link.learnNostrAddress(any(), any())).thenReturn(null);
    when(() => link.publishBounty(any())).thenAnswer((i) async {
      published.add(i.positionalArguments.single as Uint8List);
    });
    when(() => link.sendBountyMessage(any(), any())).thenAnswer((i) async {
      sent.add((
        i.positionalArguments[0] as String,
        i.positionalArguments[1] as Uint8List,
      ));
    });
  });

  BountyRepository build({Future<MeshLink>? failedLink}) => BountyRepository(
    link: failedLink ?? Future.value(link),
    relays: Future.value(relays),
    keyValueStorage: KeyValueStorage(initialize: (_) async {}),
    localStorage: storage,
    clock: () => now,
  );

  Future<BountyRM> recordBy(
    NodeIdentity author, {
    String id = '0123456789abcdef',
    int status = BountyRM.statusOpen,
    int? updatedAt,
    int? expiresAt,
    String? claimant,
    Uint8List? signingKey,
  }) => BountyRM.sign(
    id: id,
    authorPeerId: author.peerId,
    signingKeyPair: author.signingKeyPair,
    signingPublicKey: signingKey ?? author.signingPublicKey,
    createdAt: nowSeconds - 60,
    expiresAt: expiresAt ?? nowSeconds + 3600,
    updatedAt: updatedAt ?? nowSeconds - 60,
    amountCents: 2500,
    status: status,
    claimantPeerId: claimant,
    title: 'Carry a booth',
    details: 'to hall B',
  );

  group('posting', () {
    test('signs, floods, caches and shows as mine', () async {
      final repo = build();
      final bounty = await repo.postBounty(
        title: '  Fix the Gradle build ',
        details: 'It fails on sync.',
        amountCents: 4000,
        expiresAt: now.add(const Duration(hours: 2)),
      );

      expect(published, hasLength(1));
      final onWire = BountyRM.decode(published.single)!;
      expect(await onWire.verify(), isTrue);
      expect(onWire.authorPeerId, me.peerId);
      expect(onWire.title, 'Fix the Gradle build');
      expect(bounty.isMine, isTrue);
      expect(bounty.status, BountyStatus.open);
      expect((await repo.getBounties().first).single.id, bounty.id);
    });

    test('refuses what the wire cannot carry or a reader cannot use', () async {
      final repo = build();
      final later = now.add(const Duration(hours: 1));
      expect(
        repo.postBounty(
          title: '',
          details: '',
          amountCents: 1,
          expiresAt: later,
        ),
        throwsA(isA<BountyValidationException>()),
      );
      expect(
        repo.postBounty(
          title: 't',
          details: '',
          amountCents: 0,
          expiresAt: later,
        ),
        throwsA(isA<BountyValidationException>()),
      );
      expect(
        repo.postBounty(
          title: 't',
          details: '',
          amountCents: 1,
          expiresAt: now,
        ),
        throwsA(isA<BountyValidationException>()),
      );
      expect(
        repo.postBounty(
          title: 'x' * 101,
          details: '',
          amountCents: 1,
          expiresAt: later,
        ),
        throwsA(isA<BountyValidationException>()),
      );
    });

    test('a radio that refuses the frame is a domain exception', () async {
      when(() => link.publishBounty(any())).thenThrow(StateError('gatt'));
      final repo = build();
      expect(
        repo.postBounty(
          title: 't',
          details: '',
          amountCents: 1,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
        throwsA(isA<BountySendException>()),
      );
    });

    test('refuses while the mesh is stopped and no relay is up', () {
      when(() => link.running).thenReturn(false);
      relays.up = false;
      final repo = build();
      expect(
        repo.postBounty(
          title: 't',
          details: '',
          amountCents: 1,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
        throwsA(isA<MeshNotRunningException>()),
      );
    });
  });

  test(
    'posts and claims over the relays alone when the radio is off',
    () async {
      when(() => link.running).thenReturn(false);
      final repo = build();
      await settle();
      records.add((await recordBy(other)).encode());
      await settle();
      await repo.claim('0123456789abcdef', note: 'from afar');
      expect(sent, hasLength(1));
      await repo.dispose();
    },
  );

  group('inbound records', () {
    test('a valid record from someone else appears', () async {
      final repo = build();
      await settle();
      records.add((await recordBy(other)).encode());
      await settle();

      final list = await repo.getBounties().first;
      expect(list, hasLength(1));
      expect(list.single.isMine, isFalse);
      expect(list.single.authorLabel, MeshLink.labelOf(other.peerId));
      expect(list.single.amountCents, 2500);
    });

    test('a tampered record is dropped', () async {
      final repo = build();
      await settle();
      final bytes = (await recordBy(other)).encode();
      bytes[1 + 8 + 8 + 32 + 32 + 15] ^= 0xff; // one byte of the amount
      records.add(bytes);
      await settle();
      expect(await repo.getBounties().first, isEmpty);
    });

    test('an unsigned record is dropped', () async {
      final repo = build();
      await settle();
      final bytes = (await recordBy(other)).encode();
      bytes.fillRange(bytes.length - 64, bytes.length, 0);
      records.add(bytes);
      await settle();
      expect(await repo.getBounties().first, isEmpty);
    });

    test(
      'a revision by a stranger is dropped, by the author accepted',
      () async {
        final repo = build();
        await settle();
        records.add((await recordBy(other)).encode());
        await settle();

        // Third node re-signs the same id as cancelled with its own key.
        records.add(
          (await recordBy(
            third,
            status: BountyRM.statusCancelled,
            updatedAt: nowSeconds,
          )).encode(),
        );
        await settle();
        expect(
          (await repo.getBounties().first).single.status,
          BountyStatus.open,
        );

        records.add(
          (await recordBy(
            other,
            status: BountyRM.statusCancelled,
            updatedAt: nowSeconds,
          )).encode(),
        );
        await settle();
        expect(
          (await repo.getBounties().first).single.status,
          BountyStatus.cancelled,
        );
      },
    );

    test('an older revision is ignored, a newer one replaces', () async {
      final repo = build();
      await settle();
      records.add(
        (await recordBy(
          other,
          status: BountyRM.statusClaimed,
          updatedAt: nowSeconds,
          claimant: third.peerId,
        )).encode(),
      );
      await settle();
      records.add((await recordBy(other, updatedAt: nowSeconds - 60)).encode());
      await settle();
      expect(
        (await repo.getBounties().first).single.status,
        BountyStatus.claimed,
      );
      records.add(
        (await recordBy(
          other,
          status: BountyRM.statusDone,
          updatedAt: nowSeconds + 1,
          claimant: third.peerId,
        )).encode(),
      );
      await settle();
      expect((await repo.getBounties().first).single.status, BountyStatus.done);
    });

    test('an expired bounty of someone else is not shown; mine is', () async {
      final repo = build();
      await settle();
      records.add((await recordBy(other, expiresAt: nowSeconds - 1)).encode());
      await settle();
      expect(await repo.getBounties().first, isEmpty);

      await repo.postBounty(
        title: 'mine',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(seconds: 1)),
      );
      // Storage says it expired a while ago; it still shows because it is mine.
      final cm = storage.bounties.values.firstWhere(
        (b) => b.authorPeerId == me.peerId,
      );
      storage.bounties[cm.id] = BountyCM(
        id: cm.id,
        authorPeerId: cm.authorPeerId,
        authorSigningKey: cm.authorSigningKey,
        record: cm.record,
        title: cm.title,
        details: cm.details,
        amountCents: cm.amountCents,
        createdAt: cm.createdAt,
        expiresAt: nowSeconds - 100,
        updatedAt: cm.updatedAt,
        status: cm.status,
        claimantPeerId: null,
      );
      logs.add(LogLine(LogLevel.info, 'tick'));
      await settle();
      expect((await repo.getBounties().first).single.isMine, isTrue);
    });
  });

  group('claims', () {
    test(
      'claiming sends a private message and records a pending claim',
      () async {
        final repo = build();
        await settle();
        records.add((await recordBy(other)).encode());
        await settle();

        await repo.claim('0123456789abcdef', note: 'five minutes away');

        expect(sent, hasLength(1));
        expect(sent.single.$1, other.peerId);
        final msg = BountyMessageRM.decode(sent.single.$2)!;
        expect(msg.kind, BountyMessageRM.kindClaim);
        expect(msg.bountyId, '0123456789abcdef');
        expect(msg.note, 'five minutes away');
        final claims = await repo.getClaims().first;
        expect(claims.single.isMine, isTrue);
        expect(claims.single.status, ClaimStatus.pending);
      },
    );

    test('my own bounty cannot be claimed by me', () async {
      final repo = build();
      final bounty = await repo.postBounty(
        title: 't',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      expect(
        repo.claim(bounty.id),
        throwsA(isA<CannotClaimOwnBountyException>()),
      );
    });

    test('a claim on a closed bounty is refused', () async {
      final repo = build();
      await settle();
      records.add(
        (await recordBy(other, status: BountyRM.statusCancelled)).encode(),
      );
      await settle();
      expect(
        repo.claim('0123456789abcdef'),
        throwsA(isA<BountyClosedException>()),
      );
    });

    test('an inbound claim on my bounty is recorded from its sender', () async {
      final repo = build();
      final bounty = await repo.postBounty(
        title: 't',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      messages.add((
        from: other.peerId,
        body: BountyMessageRM(
          kind: BountyMessageRM.kindClaim,
          bountyId: bounty.id,
          sentAt: nowSeconds,
          note: 'me!',
        ).encode(),
      ));
      await settle();

      final claims = await repo.getClaims().first;
      expect(claims.single.claimantId, other.peerId);
      expect(claims.single.isMine, isFalse);
      expect(claims.single.note, 'me!');
    });

    test(
      'accepting publishes a claimed revision and answers everyone',
      () async {
        final repo = build();
        final bounty = await repo.postBounty(
          title: 't',
          details: '',
          amountCents: 1,
          expiresAt: now.add(const Duration(hours: 1)),
        );
        for (final who in [other, third]) {
          messages.add((
            from: who.peerId,
            body: BountyMessageRM(
              kind: BountyMessageRM.kindClaim,
              bountyId: bounty.id,
              sentAt: nowSeconds,
              note: '',
            ).encode(),
          ));
        }
        await settle();
        published.clear();

        await repo.accept(bounty.id, other.peerId);

        final revision = BountyRM.decode(published.single)!;
        expect(await revision.verify(), isTrue);
        expect(revision.status, BountyRM.statusClaimed);
        expect(revision.claimantPeerId, other.peerId);
        expect(revision.updatedAt, greaterThan(nowSeconds - 1));

        final byPeer = {
          for (final s in sent) s.$1: BountyMessageRM.decode(s.$2)!.kind,
        };
        expect(byPeer[other.peerId], BountyMessageRM.kindAccept);
        expect(byPeer[third.peerId], BountyMessageRM.kindDecline);

        final claims = await repo.getClaims().first;
        expect(
          claims.firstWhere((c) => c.claimantId == other.peerId).status,
          ClaimStatus.accepted,
        );
        expect(
          claims.firstWhere((c) => c.claimantId == third.peerId).status,
          ClaimStatus.declined,
        );
      },
    );

    test('a public revision tells me where my claim stands', () async {
      final repo = build();
      await settle();
      records.add((await recordBy(other)).encode());
      await settle();
      await repo.claim('0123456789abcdef');

      records.add(
        (await recordBy(
          other,
          status: BountyRM.statusClaimed,
          updatedAt: nowSeconds,
          claimant: third.peerId,
        )).encode(),
      );
      await settle();
      expect(
        (await repo.getClaims().first).single.status,
        ClaimStatus.declined,
      );
    });

    test('a claim that arrives is acknowledged to its sender', () async {
      final repo = build();
      final bounty = await repo.postBounty(
        title: 't',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      messages.add((
        from: other.peerId,
        body: BountyMessageRM(
          kind: BountyMessageRM.kindClaim,
          bountyId: bounty.id,
          sentAt: nowSeconds,
          note: '',
        ).encode(),
      ));
      await settle();
      final receipt = sent.single;
      expect(receipt.$1, other.peerId);
      expect(
        BountyMessageRM.decode(receipt.$2)!.kind,
        BountyMessageRM.kindReceived,
      );
    });

    test('a receipt marks my claim delivered and stops the repeats', () {
      fakeAsync((async) {
        final repo = build();
        async.elapse(const Duration(milliseconds: 10));
        recordBy(other).then((r) => records.add(r.encode()));
        async.elapse(const Duration(milliseconds: 50));
        repo.claim('0123456789abcdef');
        async.elapse(const Duration(milliseconds: 10));
        expect(sent, hasLength(1));

        messages.add((
          from: other.peerId,
          body: BountyMessageRM(
            kind: BountyMessageRM.kindReceived,
            bountyId: '0123456789abcdef',
            sentAt: nowSeconds,
            note: '',
          ).encode(),
        ));
        async.elapse(const Duration(milliseconds: 50));
        final seen = <List<Claim>>[];
        final sub = repo.getClaims().listen(seen.add);
        async.elapse(const Duration(milliseconds: 50));
        expect(seen, isNotEmpty, reason: 'no claims emitted');
        final mine = seen.last.single;
        expect(mine.delivered, isTrue);
        expect(mine.status, ClaimStatus.pending);
        sub.cancel();

        when(() => link.canReach(other.peerId)).thenReturn(true);
        async.elapse(BountyRepository.republishEvery);
        async.elapse(const Duration(milliseconds: 10));
        expect(sent, hasLength(1));
        repo.dispose();
      });
    });

    test(
      'a withdrawn claim is dropped, and a claimed bounty reopens',
      () async {
        final repo = build();
        final bounty = await repo.postBounty(
          title: 't',
          details: '',
          amountCents: 1,
          expiresAt: now.add(const Duration(hours: 1)),
        );
        messages.add((
          from: other.peerId,
          body: BountyMessageRM(
            kind: BountyMessageRM.kindClaim,
            bountyId: bounty.id,
            sentAt: nowSeconds,
            note: '',
          ).encode(),
        ));
        await settle();
        await repo.accept(bounty.id, other.peerId);
        published.clear();

        messages.add((
          from: other.peerId,
          body: BountyMessageRM(
            kind: BountyMessageRM.kindWithdraw,
            bountyId: bounty.id,
            sentAt: nowSeconds,
            note: '',
          ).encode(),
        ));
        await settle();

        expect(await repo.getClaims().first, isEmpty);
        final reopened = BountyRM.decode(published.single)!;
        expect(reopened.status, BountyRM.statusOpen);
        expect(reopened.claimantPeerId, isNull);
        expect(
          (await repo.getBounties().first).single.status,
          BountyStatus.open,
        );
      },
    );

    test('only the author can accept', () async {
      final repo = build();
      await settle();
      records.add((await recordBy(other)).encode());
      await settle();
      expect(
        repo.accept('0123456789abcdef', third.peerId),
        throwsA(isA<NotBountyAuthorException>()),
      );
    });
  });

  group('lifecycle', () {
    test('done and paid follow claimed, cancel is final', () async {
      final repo = build();
      final bounty = await repo.postBounty(
        title: 't',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      expect(repo.markDone(bounty.id), throwsA(isA<BountyClosedException>()));
      messages.add((
        from: other.peerId,
        body: BountyMessageRM(
          kind: BountyMessageRM.kindClaim,
          bountyId: bounty.id,
          sentAt: nowSeconds,
          note: '',
        ).encode(),
      ));
      await settle();
      await repo.accept(bounty.id, other.peerId);
      await repo.markDone(bounty.id);
      await repo.markPaid(bounty.id);
      final b = (await repo.getBounties().first).single;
      expect(b.status, BountyStatus.paid);
      expect(repo.cancel(bounty.id), throwsA(isA<BountyClosedException>()));
    });

    test('the accepted claimant marks done privately', () async {
      final repo = build();
      await settle();
      records.add((await recordBy(other)).encode());
      await settle();
      await repo.claim('0123456789abcdef');
      messages.add((
        from: other.peerId,
        body: BountyMessageRM(
          kind: BountyMessageRM.kindAccept,
          bountyId: '0123456789abcdef',
          sentAt: nowSeconds,
          note: '',
        ).encode(),
      ));
      await settle();
      sent.clear();

      await repo.markDone('0123456789abcdef');

      expect(
        BountyMessageRM.decode(sent.single.$2)!.kind,
        BountyMessageRM.kindDone,
      );
      expect((await repo.getClaims().first).single.status, ClaimStatus.done);
    });
  });

  group('gossip', () {
    test(
      'a newcomer met before anything was posted is not on cooldown',
      () async {
        final repo = build();
        await settle();
        // Peer arrives while the board is empty.
        when(() => link.neighbours).thenReturn({third.peerId});
        logs.add(LogLine(LogLevel.info, 'hello'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(published, isEmpty);

        // Peer drops, a bounty arrives, peer comes back.
        when(() => link.neighbours).thenReturn(const {});
        logs.add(LogLine(LogLevel.info, 'gone'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        records.add((await recordBy(other)).encode());
        await settle();
        when(() => link.neighbours).thenReturn({third.peerId});
        logs.add(LogLine(LogLevel.info, 'back'));
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(published, hasLength(1));
        await repo.dispose();
      },
    );

    test('a newcomer gets the open records once', () async {
      final repo = build();
      await settle();
      records.add((await recordBy(other)).encode());
      records.add(
        (await recordBy(
          other,
          id: 'fedcba9876543210',
          status: BountyRM.statusCancelled,
        )).encode(),
      );
      await settle();

      when(() => link.neighbours).thenReturn({third.peerId});
      logs.add(LogLine(LogLevel.info, 'hello'));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(published, hasLength(1));
      expect(BountyRM.decode(published.single)!.id, '0123456789abcdef');

      logs.add(LogLine(LogLevel.info, 'again'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(published, hasLength(1));
      await repo.dispose();
    });
  });

  test('a broken cache is a domain exception on both paths', () async {
    final broken = _BrokenStorage();
    final repo = BountyRepository(
      link: Future.value(link),
      relays: Future.value(relays),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      localStorage: broken,
      clock: () => now,
    );
    expect(repo.cacheFailures, emits(isA<BountyCacheException>()));
    await settle();
    expect(
      repo.postBounty(
        title: 't',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      throwsA(isA<BountyCacheException>()),
    );
  });

  test('a newcomer gets every open record, mine and other people\'s', () async {
    final repo = build();
    await repo.postBounty(
      title: 'mine',
      details: '',
      amountCents: 1,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    records.add((await recordBy(other)).encode());
    await settle();
    published.clear();

    when(() => link.neighbours).thenReturn({third.peerId});
    logs.add(LogLine(LogLevel.info, 'hello'));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(published, hasLength(2));
    await repo.dispose();
  });

  test('a pending claim is offered again while the author is in range', () {
    fakeAsync((async) {
      final repo = build();
      async.elapse(const Duration(milliseconds: 10));
      recordBy(other).then((r) => records.add(r.encode()));
      async.elapse(const Duration(milliseconds: 50));
      repo.claim('0123456789abcdef', note: 'soon');
      async.elapse(const Duration(milliseconds: 10));
      expect(sent, hasLength(1));

      // Author not in range: nothing to say to nobody.
      async.elapse(BountyRepository.republishEvery);
      async.elapse(const Duration(milliseconds: 10));
      expect(sent, hasLength(1));

      when(() => link.canReach(other.peerId)).thenReturn(true);
      async.elapse(BountyRepository.republishEvery);
      async.elapse(const Duration(milliseconds: 10));
      expect(sent, hasLength(2));
      final again = BountyMessageRM.decode(sent.last.$2)!;
      expect(again.kind, BountyMessageRM.kindClaim);
      expect(again.note, 'soon');
      repo.dispose();
    });
  });

  test('coming back to the foreground says pending claims again now', () {
    fakeAsync((async) {
      final repo = build();
      async.elapse(const Duration(milliseconds: 10));
      recordBy(other).then((r) => records.add(r.encode()));
      async.elapse(const Duration(milliseconds: 50));
      repo.claim('0123456789abcdef', note: 'soon');
      async.elapse(const Duration(milliseconds: 10));
      expect(sent, hasLength(1));

      when(() => link.canReach(other.peerId)).thenReturn(true);
      repo.resume();
      async.elapse(const Duration(milliseconds: 10));
      expect(sent, hasLength(2));
      repo.dispose();
    });
  });

  test('a pending claim is offered again over the internet, radio off', () {
    fakeAsync((async) {
      when(() => link.running).thenReturn(false);
      final repo = build();
      async.elapse(const Duration(milliseconds: 10));
      recordBy(other).then((r) => records.add(r.encode()));
      async.elapse(const Duration(milliseconds: 50));
      repo.claim('0123456789abcdef', note: 'soon');
      async.elapse(const Duration(milliseconds: 10));
      expect(sent, hasLength(1));

      // The author's internet address is known, so the claim goes again
      // even though the radio never started.
      when(() => link.canReach(other.peerId)).thenReturn(true);
      async.elapse(BountyRepository.republishEvery);
      async.elapse(const Duration(milliseconds: 10));
      expect(sent, hasLength(2));
      expect(published, isEmpty);
      repo.dispose();
    });
  });

  test('my open bounties go out again on the republish cadence', () {
    fakeAsync((async) {
      final repo = build();
      async.elapse(const Duration(milliseconds: 10));
      when(() => link.neighbours).thenReturn({other.peerId});
      repo.postBounty(
        title: 'mine',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      async.elapse(const Duration(milliseconds: 10));
      expect(published, hasLength(1));

      async.elapse(BountyRepository.republishEvery);
      async.elapse(const Duration(milliseconds: 10));
      expect(published, hasLength(2));
      final first = BountyRM.decode(published.first)!;
      final renewed = BountyRM.decode(published.last)!;
      expect(renewed.title, 'mine');
      // A renewal is a fresh signature over a newer timestamp: proof of
      // life, not a repeat of bytes everyone already has.
      expect(renewed.updatedAt, greaterThan(first.updatedAt));
      expect(renewed.signature, isNot(first.signature));
      expect(renewed.status, BountyRM.statusOpen);

      // Nobody in range and no relay: no point shouting.
      when(() => link.neighbours).thenReturn(const {});
      relays.up = false;
      async.elapse(BountyRepository.republishEvery);
      async.elapse(const Duration(milliseconds: 10));
      expect(published, hasLength(2));
      repo.dispose();
    });
  });

  test('a renewal goes to the relays alone when nobody is in radio range', () {
    fakeAsync((async) {
      final repo = build();
      async.elapse(const Duration(milliseconds: 10));
      when(() => link.neighbours).thenReturn({other.peerId});
      repo.postBounty(
        title: 'mine',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      async.elapse(const Duration(milliseconds: 10));
      final listedBefore = relays.published.length;

      when(() => link.neighbours).thenReturn(const {});
      async.elapse(BountyRepository.republishEvery);
      async.elapse(const Duration(milliseconds: 10));
      expect(published, hasLength(1));
      expect(relays.published.length, greaterThan(listedBefore));
      repo.dispose();
    });
  });

  test('a bounty whose poster went quiet for two leases is hidden', () async {
    final repo = build();
    await settle();
    final quiet = nowSeconds - Bounty.posterLapse.inSeconds;
    records.add((await recordBy(other, updatedAt: quiet)).encode());
    records.add(
      (await recordBy(
        other,
        id: 'fedcba9876543210',
        updatedAt: nowSeconds - 30,
      )).encode(),
    );
    await settle();
    final list = await repo.getBounties().first;
    expect(list.map((b) => b.id), ['fedcba9876543210']);
    await repo.dispose();
  });

  group('retiring the identity', () {
    test(
      'the outlook lists what is open and whether anyone can hear',
      () async {
        final repo = build();
        await settle();
        await repo.postBounty(
          title: 'Carry a booth',
          details: '',
          amountCents: 1,
          expiresAt: now.add(const Duration(hours: 1)),
        );
        records.add((await recordBy(other)).encode());
        await settle();
        await repo.claim('0123456789abcdef');

        final outlook = await repo.retirementOutlook();
        expect(outlook.openBountyTitles, ['Carry a booth']);
        expect(outlook.pendingClaimCount, 1);
        expect(outlook.canAnnounce, isTrue); // relays are up in the fake

        relays.up = false;
        when(() => link.running).thenReturn(false);
        expect((await repo.retirementOutlook()).canAnnounce, isFalse);
      },
    );

    test(
      'retiring cancels mine, retracts the listing, withdraws my claims',
      () async {
        final repo = build();
        await settle();
        when(() => link.neighbours).thenReturn({other.peerId});
        final bounty = await repo.postBounty(
          title: 'Carry a booth',
          details: '',
          amountCents: 1,
          expiresAt: now.add(const Duration(hours: 1)),
        );
        records.add((await recordBy(other)).encode());
        await settle();
        when(() => link.canReach(other.peerId)).thenReturn(true);
        await repo.claim('0123456789abcdef');
        published.clear();
        sent.clear();
        relays.published.clear();

        await repo.retireIdentity(flush: Duration.zero);

        final cancelled = BountyRM.decode(published.single)!;
        expect(cancelled.id, bounty.id);
        expect(cancelled.status, BountyRM.statusCancelled);
        expect(await cancelled.verify(), isTrue);
        expect(relays.published.map((e) => e.kind), containsAll([30402, 5]));

        final withdraw = BountyMessageRM.decode(sent.single.$2)!;
        expect(sent.single.$1, other.peerId);
        expect(withdraw.kind, BountyMessageRM.kindWithdraw);
        expect(withdraw.bountyId, '0123456789abcdef');

        final mine = (await repo.getBounties().first).firstWhere(
          (b) => b.isMine,
        );
        expect(mine.status, BountyStatus.cancelled);
      },
    );

    test('retiring with nothing open touches nothing', () async {
      final repo = build();
      await settle();
      await repo.retireIdentity(flush: Duration.zero);
      expect(published, isEmpty);
      expect(sent, isEmpty);
    });
  });

  group('reaching the author over the internet', () {
    test('a post carries our nostr key', () async {
      final repo = build();
      await repo.postBounty(
        title: 'mine',
        details: '',
        amountCents: 1,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      final rm = BountyRM.decode(published.single)!;
      final ours = await NostrIdentity.fromSeed(me.seed);
      expect(rm.authorNostrKeyHex, ours.publicKeyHex);
    });

    test('an inbound record teaches the link where its author lives', () async {
      final repo = build();
      await settle();
      final theirs = await NostrIdentity.fromSeed(other.seed);
      final rm = await BountyRM.sign(
        id: '0123456789abcdef',
        authorPeerId: other.peerId,
        signingKeyPair: other.signingKeyPair,
        signingPublicKey: other.signingPublicKey,
        nostrPublicKey: Uint8List.fromList([
          for (var i = 0; i < 64; i += 2)
            int.parse(theirs.publicKeyHex.substring(i, i + 2), radix: 16),
        ]),
        createdAt: nowSeconds - 60,
        expiresAt: nowSeconds + 3600,
        updatedAt: nowSeconds - 60,
        amountCents: 100,
        status: BountyRM.statusOpen,
        claimantPeerId: null,
        title: 't',
        details: '',
      );
      records.add(rm.encode());
      await settle();
      verify(
        () => link.learnNostrAddress(other.peerId, theirs.publicKeyHex),
      ).called(1);
      await repo.dispose();
    });
  });

  group('internet board', () {
    test('a post is also published as a listing', () async {
      final repo = build();
      await settle();
      await repo.postBounty(
        title: 'mine',
        details: '',
        amountCents: 2150,
        expiresAt: now.add(const Duration(hours: 1)),
        geohash: const Geohash('ud9d5'),
      );
      await settle();
      expect(relays.published, hasLength(1));
      final event = relays.published.single;
      expect(event.kind, NostrBoard.listingKind);
      expect(
        event.tags.where((t) => t[0] == 'g').map((t) => t[1]),
        contains('ud9d'),
      );
      final carried = BountyRM.decode(NostrBoard.recordOf(event)!)!;
      expect(carried.geohash, 'ud9d5');
    });

    test('following an area subscribes at city precision', () async {
      final repo = build();
      await settle();
      await repo.followArea(const Geohash('ud9d5'));
      await settle();
      expect(relays.subscriptions, hasLength(1));
      expect(relays.subscriptions.single.single.tagFilters!['g'], ['ud9d']);
    });

    test(
      'a listing from the internet shows as such until the radio hears it',
      () async {
        final repo = build();
        await settle();
        final rm = await recordBy(other);
        final board = NostrBoard(
          identity: await NostrIdentity.fromSeed(
            Uint8List.fromList(List.filled(32, 9)),
          ),
          client: relays,
        );
        relays.incoming.add(board.buildEvent(rm));
        await settle();
        var list = await repo.getBounties().first;
        expect(list.single.viaInternet, isTrue);

        // The very same revision heard on the radio: not news, but proof the
        // poster is within reach.
        records.add(rm.encode());
        await settle();
        list = await repo.getBounties().first;
        expect(list.single.viaInternet, isFalse);
      },
    );
  });

  test('dispose completes when the identity never loaded', () async {
    final repo = build(failedLink: Future.error(StateError('vault')));
    await repo.dispose();
  });
}
