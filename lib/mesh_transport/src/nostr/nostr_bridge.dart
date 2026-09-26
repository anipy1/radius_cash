import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nostr/nostr.dart';

import '../identity/nostr_identity.dart';
import 'relay_transport.dart';

/// Carries mesh frames over the internet when the radio cannot.
///
/// What travels is the sealed frame itself, byte for byte, so the Noise
/// session is doing exactly the same work it does over BLE. The gift wrap is
/// an envelope around it, not a replacement for it: relays see a kind 1059
/// from an ephemeral key to a recipient, and nothing about who is really
/// talking or what they said.
///
/// That means two layers of encryption for one message, which sounds wasteful
/// and is not. The Noise session is what the recipient authenticates; NIP-44
/// is what keeps the relay from learning the sender. Dropping either would
/// lose something the other does not provide.
/// One frame off the internet and who sealed it.
class NostrInbound {
  const NostrInbound(this.bytes, this.fromPubkeyHex);

  final Uint8List bytes;
  final String fromPubkeyHex;
}

class NostrBridge {
  NostrBridge({
    required this.identity,
    required this.client,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final NostrIdentity identity;
  final RelayTransport client;
  final DateTime Function() _now;

  /// Gift wrap. Relays that carry these usually want NIP-42 first.
  static const giftWrapKind = 1059;

  /// How old a rumour may be and still be handed to the mesh.
  ///
  /// The subscription reaches two days back because the wrap's timestamp is
  /// randomised, but the rumour inside carries the real one. Every frame that
  /// travels this way is ephemeral: a handshake step, a sealed message that
  /// only opens under the session that exists now. The mesh dedupes by
  /// message id, but only in memory, so a restart used to replay two days of
  /// old handshakes and answer each of them, which broke the live one.
  ///
  /// Two minutes is generous. Relays deliver in seconds, a handshake gives
  /// up after twenty, and a pending claim is said again every two minutes.
  static const maxAge = Duration(minutes: 2);

  final _inbound = StreamController<NostrInbound>.broadcast();
  StreamSubscription<Event>? _events;
  String? _subscriptionId;

  /// Frame bytes recovered from gift wraps addressed to us, with the Nostr
  /// key of whoever sealed the rumour.
  ///
  /// The bytes are exactly what came off a radio, so the caller can feed
  /// them into the same inbound path without caring which pipe they arrived
  /// on. The sender is what the radio never gives: an address to answer to.
  Stream<NostrInbound> get inbound => _inbound.stream;

  bool get isConnected => client.isConnected;

  void start() {
    _events = client.events.listen(_onEvent);
    client.open();
    _subscriptionId = client.subscribe([
      Filter(
        kinds: const [giftWrapKind],
        pTags: [identity.publicKeyHex],
        // Two days back, not "now", and the difference is not a margin for
        // clock skew. NIP-59 deliberately randomises a gift wrap's created_at
        // into the past so that timestamps cannot be correlated, by up to two
        // days. A since of now therefore filters out messages that were sent
        // seconds ago, which is exactly what it looked like: publishes were
        // accepted and nothing ever arrived.
        //
        // Re-delivery of something already seen costs nothing, because the
        // mesh dedupes frames by message id regardless of which pipe brought
        // them.
        since:
            DateTime.now()
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch ~/
            1000,
      ),
    ]);
  }

  /// Publishes [frameBytes] to [recipientPubkeyHex].
  ///
  /// Returns false when there is nothing to publish through, rather than
  /// throwing: an unreachable relay is an ordinary condition here, and the
  /// caller has an outbox for exactly this.
  Future<bool> send(String recipientPubkeyHex, Uint8List frameBytes) async {
    if (!client.isConnected) return false;
    try {
      final wrap = await DirectMessage.create(
        // Base64 because a rumor's content is a string and frame bytes are
        // not text. It costs a third more bytes, which matters on a radio and
        // does not matter here.
        message: base64Encode(frameBytes),
        authorSecretKey: identity.privateKeyHex,
        recipientPubkey: recipientPubkeyHex,
      );
      client.publish(wrap);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onEvent(Event event) async {
    if (event.kind != giftWrapKind) return;
    try {
      final rumor = await DirectMessage.parse(
        giftWrap: event,
        recipientSecretKey: identity.privateKeyHex,
      );
      final sentAt = DateTime.fromMillisecondsSinceEpoch(
        rumor.createdAt * 1000,
      );
      if (_now().difference(sentAt) > maxAge) return;
      final bytes = base64Decode(rumor.content);
      if (bytes.isEmpty) return;
      if (!_inbound.isClosed) {
        _inbound.add(
          NostrInbound(Uint8List.fromList(bytes), rumor.pubkey.toLowerCase()),
        );
      }
    } catch (_) {
      // A wrap we cannot open is not an error worth reporting. Relays deliver
      // whatever matches the filter, and a filter on recipient will match
      // things sealed with keys we have since rotated away from.
    }
  }

  /// Stops listening. The client is shared with the board and is closed by
  /// whoever created it.
  Future<void> close() async {
    final id = _subscriptionId;
    if (id != null) client.unsubscribe(id);
    await _events?.cancel();
    await _inbound.close();
  }
}
