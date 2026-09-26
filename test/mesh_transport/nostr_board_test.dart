import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart' hide Tags;
import 'package:radius/mesh_transport/src/bounty/bounty_rm.dart';
import 'package:radius/mesh_transport/src/identity/node_identity.dart';
import 'package:radius/mesh_transport/src/identity/nostr_identity.dart';
import 'package:radius/mesh_transport/src/nostr/nostr_board.dart';
import 'package:radius/mesh_transport/src/nostr/relay_client.dart';
import 'package:radius/mesh_transport/src/nostr/relay_transport.dart';

class _FakeRelays implements RelayTransport {
  final incoming = StreamController<Event>.broadcast();
  final published = <Event>[];
  final subscriptions = <String, List<Filter>>{};
  final closedSubscriptions = <String>[];
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
    final id = subscriptionId ?? 'sub${subscriptions.length}';
    subscriptions[id] = filters;
    return id;
  }

  @override
  void unsubscribe(String subscriptionId) =>
      closedSubscriptions.add(subscriptionId);
  @override
  void publish(Event event) => published.add(event);
  @override
  Future<void> close() async {}
}

void main() {
  late NodeIdentity node;
  late NostrIdentity nostr;
  late _FakeRelays relays;
  late NostrBoard board;

  setUpAll(() async {
    final seed = Uint8List.fromList(List.generate(32, (i) => i + 3));
    node = await NodeIdentity.fromSeed(seed);
    nostr = await NostrIdentity.fromSeed(seed);
  });

  setUp(() {
    relays = _FakeRelays();
    board = NostrBoard(identity: nostr, client: relays)..start();
  });

  Future<BountyRM> record({int amountCents = 2150, String geohash = 'ud9d5'}) =>
      BountyRM.sign(
        id: '0123456789abcdef',
        authorPeerId: node.peerId,
        signingKeyPair: node.signingKeyPair,
        signingPublicKey: node.signingPublicKey,
        createdAt: 1800000000,
        expiresAt: 1800003600,
        updatedAt: 1800000000,
        amountCents: amountCents,
        status: BountyRM.statusOpen,
        claimantPeerId: null,
        title: 'Carry a booth',
        details: 'Hall B',
        geohash: geohash,
      );

  group('NostrBoard:', () {
    test('When publishing, the listing is a proper NIP-99 event', () async {
      final rm = await record();
      expect(await board.publish(rm), isTrue);

      final event = relays.published.single;
      expect(event.kind, 30402);
      expect(event.pubkey, nostr.publicKeyHex);
      expect(event.content, 'Hall B');
      String tag(String name) => event.tags.firstWhere((t) => t[0] == name)[1];
      expect(tag('d'), '0123456789abcdef');
      expect(tag('title'), 'Carry a booth');
      expect(event.tags.firstWhere((t) => t[0] == 'price'), [
        'price',
        '21.50',
        'EUR',
      ]);
      expect(tag('status'), 'active');
      expect(tag('expiration'), '1800003600');
      expect(tag('t'), NostrBoard.topic);
      expect(event.tags.where((t) => t[0] == 'g').map((t) => t[1]).toList(), [
        'u',
        'ud',
        'ud9',
        'ud9d',
        'ud9d5',
      ]);
      // The signed record travels whole and still verifies.
      final carried = BountyRM.decode(NostrBoard.recordOf(event)!)!;
      expect(carried.id, rm.id);
      expect(await carried.verify(), isTrue);
    });

    test('When the amount is whole euros, the price has no decimals', () async {
      final event = board.buildEvent(await record(amountCents: 4000));
      expect(event.tags.firstWhere((t) => t[0] == 'price')[1], '40');
    });

    test(
      'When retracting, asks relays to delete the listing (NIP-09)',
      () async {
        final rm = await record();
        expect(await board.retract(rm), isTrue);

        final event = relays.published.single;
        expect(event.kind, 5);
        expect(event.pubkey, nostr.publicKeyHex);
        expect(
          event.tags.firstWhere((t) => t[0] == 'a')[1],
          '30402:${nostr.publicKeyHex}:0123456789abcdef',
        );
        expect(event.tags.firstWhere((t) => t[0] == 'k')[1], '30402');
      },
    );

    test('When no relay is up, publish says so instead of throwing', () async {
      relays.up = false;
      expect(await board.publish(await record()), isFalse);
    });

    test('When following an area, subscribes by topic and geohash prefix', () {
      board.follow('ud9d');
      final filter = relays.subscriptions.values.single.single;
      expect(filter.kinds, [30402]);
      expect(filter.tagFilters!['t'], [NostrBoard.topic]);
      expect(filter.tagFilters!['g'], ['ud9d']);
      expect(filter.since, isNotNull);

      board.follow('u4pr');
      expect(relays.closedSubscriptions, hasLength(1));
      expect(relays.subscriptions, hasLength(2));
    });

    test(
      'When a listing arrives, its record comes out; junk does not',
      () async {
        final seen = <Uint8List>[];
        board.records.listen(seen.add);
        final rm = await record();
        relays.incoming.add(board.buildEvent(rm));
        relays.incoming.add(
          Event.from(
            kind: 30402,
            content: 'no record here',
            secretKey: nostr.privateKeyHex,
            tags: [
              ['d', 'x'],
              ['t', NostrBoard.topic],
            ],
          ),
        );
        relays.incoming.add(
          Event.from(
            kind: 30402,
            content: 'bad base64',
            secretKey: nostr.privateKeyHex,
            tags: [
              [NostrBoard.recordTag, '***'],
            ],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(seen, hasLength(1));
        expect(seen.single, rm.encode());
      },
    );
  });
}
