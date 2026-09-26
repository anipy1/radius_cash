import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nostr/nostr.dart';

import '../bounty/bounty_rm.dart';
import '../identity/nostr_identity.dart';
import 'relay_transport.dart';

/// Bounties on the internet, as NIP-99 classified listings.
///
/// Every open bounty is also a kind 30402 event: title, summary, a price
/// in EUR, a status, an expiry, and `g` tags for every prefix of the
/// poster's geohash so it can be found by area at any precision. Any Nostr
/// client that reads listings sees an ordinary listing. A Radius client
/// also finds the signed record itself in a `radius` tag, verifies it the
/// same way as one heard on the radio, and treats it as the truth; the
/// event's own author key is just who carried it.
class NostrBoard {
  NostrBoard({required this.identity, required this.client});

  final NostrIdentity identity;
  final RelayTransport client;

  static const listingKind = 30402;

  /// The `t` tag every Radius listing carries, so a reader can ask relays
  /// for these and nothing else.
  static const topic = 'radius-bounty';

  /// The tag holding the signed record, base64.
  static const recordTag = 'radius';

  /// How far back to ask for listings. A bounty lives a day or three.
  static const lookback = Duration(days: 3);

  final _records = StreamController<Uint8List>.broadcast();
  StreamSubscription<Event>? _events;
  String? _subscriptionId;

  /// Signed records recovered from listings, exactly as the record layer
  /// wants them.
  Stream<Uint8List> get records => _records.stream;

  void start() {
    _events ??= client.events.listen(_onEvent);
  }

  /// Follows listings whose geohash starts with [areaPrefix]. Replaces any
  /// earlier area.
  void follow(String areaPrefix) {
    final old = _subscriptionId;
    if (old != null) client.unsubscribe(old);
    _subscriptionId = client.subscribe([
      Filter(
        kinds: const [listingKind],
        tagFilters: {
          't': [topic],
          'g': [areaPrefix],
        },
        since: DateTime.now().subtract(lookback).millisecondsSinceEpoch ~/ 1000,
      ),
    ]);
  }

  /// Publishes [rm] as a listing. Returns false when no relay is reachable.
  Future<bool> publish(BountyRM rm) async {
    if (!client.isConnected) return false;
    try {
      client.publish(buildEvent(rm));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The listing for [rm], signed by our Nostr key.
  /// Asks relays to drop the listing (NIP-09), for a bounty that is never
  /// coming back. A cancelled revision already replaces the listing, but a
  /// relay that saw neither still serves the old one; the deletion covers
  /// that, and it is what a phone that is about to forget its key can do
  /// while it still has it.
  ///
  /// Deletion kind, NIP-09.
  static const deletionKind = 5;

  Future<bool> retract(BountyRM rm) async {
    if (!client.isConnected) return false;
    try {
      client.publish(
        Event.from(
          kind: deletionKind,
          content: 'cancelled',
          secretKey: identity.privateKeyHex,
          tags: [
            ['a', '$listingKind:${identity.publicKeyHex}:${rm.id}'],
            ['k', '$listingKind'],
          ],
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Event buildEvent(BountyRM rm) {
    final euros = rm.amountCents ~/ 100;
    final cents = rm.amountCents % 100;
    final price = cents == 0
        ? '$euros'
        : '$euros.${cents.toString().padLeft(2, '0')}';
    final geohashTags = [
      for (var i = 1; i <= rm.geohash.length; i++)
        ['g', rm.geohash.substring(0, i)],
    ];
    return Event.from(
      kind: listingKind,
      content: rm.details,
      secretKey: identity.privateKeyHex,
      createdAt: rm.updatedAt,
      tags: [
        // One listing per bounty: a newer event with the same d replaces it.
        ['d', rm.id],
        ['title', rm.title],
        ['summary', rm.details],
        ['published_at', '${rm.createdAt}'],
        ['price', price, 'EUR'],
        ['status', rm.status == BountyRM.statusOpen ? 'active' : 'sold'],
        ['expiration', '${rm.expiresAt}'],
        ['t', topic],
        ...geohashTags,
        [recordTag, base64Encode(rm.encode())],
      ],
    );
  }

  /// The signed record inside a listing, or null when there is none.
  static Uint8List? recordOf(Event event) {
    if (event.kind != listingKind) return null;
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == recordTag) {
        try {
          return Uint8List.fromList(base64Decode(tag[1]));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  void _onEvent(Event event) {
    final record = recordOf(event);
    if (record == null || record.isEmpty) return;
    if (!_records.isClosed) _records.add(record);
  }

  Future<void> close() async {
    final id = _subscriptionId;
    if (id != null) client.unsubscribe(id);
    await _events?.cancel();
    await _records.close();
  }
}
