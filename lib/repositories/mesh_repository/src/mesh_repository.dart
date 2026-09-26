import 'dart:async';

import 'package:collection/collection.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/keep_alive/keep_alive.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:rxdart/rxdart.dart';

import 'mappers/mappers.dart';

/// The radio and the relays, as the rest of the app sees them.
///
/// Features get peers and status as streams and never learn that a MeshLink
/// exists. The link is shared with every repository that speaks to the mesh
/// and only exists once the identity has loaded, so every method waits on it
/// rather than making callers order their calls.
class MeshRepository {
  MeshRepository({
    required Future<MeshLink> link,
    required Future<RelayTransport> relays,
    KeepAlive keepAlive = const NoKeepAlive(),
  }) : _link = link,
       _relays = relays,
       _keepAlive = keepAlive {
    // A failed identity load is reported by whichever method first needs the
    // link, as IdentityLoadException. Without this the same failure would also
    // surface as an unhandled error from a future nobody has awaited yet.
    _link.ignore();
    _relays.ignore();
  }

  /// Shared with the bounty repository, which publishes listings through
  /// the same pool the bridge carries private messages on.
  final Future<RelayTransport> _relays;

  final Future<MeshLink> _link;

  /// Holds the process up while the radio runs. See [KeepAlive].
  final KeepAlive _keepAlive;

  final _peers = BehaviorSubject<List<Peer>>.seeded(const []);
  final _meshStatus = BehaviorSubject<MeshStatus>.seeded(MeshStatus.stopped);
  final _relayStatus = BehaviorSubject<RelayStatus>.seeded(RelayStatus.stopped);

  StreamSubscription<Object?>? _snapshots;
  bool _observing = false;

  NostrBridge? _bridge;
  StreamSubscription<Object?>? _inbound;
  StreamSubscription<Object?>? _relayChanges;

  /// Every peer we can address, re-emitted whenever the set or any flag
  /// changes.
  Stream<List<Peer>> getPeers() {
    _observe();
    return _peers.stream.distinct(const ListEquality<Peer>().equals);
  }

  Stream<MeshStatus> getMeshStatus() {
    _observe();
    return _meshStatus.stream.distinct();
  }

  Stream<RelayStatus> getRelayStatus() => _relayStatus.stream.distinct();

  /// Takes snapshots of the link's state whenever it logs something.
  ///
  /// The link exposes its peers and state as getters, not streams, and the
  /// old UI rebuilt on every log line for exactly this reason: nothing about
  /// a peer changes without a line being logged. Throttled, because a burst
  /// of fragments logs dozens of lines in a second and one snapshot after the
  /// burst is as good as thirty during it.
  void _observe() {
    if (_observing) return;
    _observing = true;
    _link.then((link) {
      _snapshot(link);
      _snapshots = link.logs
          .throttleTime(const Duration(milliseconds: 300), trailing: true)
          .listen((_) => _snapshot(link));
    }).ignore();
  }

  void _snapshot(MeshLink link) {
    if (_peers.isClosed) return;
    _peers.add(link.toPeers());
    _meshStatus.add(link.toMeshStatus());
  }

  /// Brings the radio up. Resolves once the link is scanning, or once it has
  /// decided to wait for Bluetooth to be switched on; the status stream tells
  /// the two apart.
  Future<void> start() async {
    final link = await _identityOrThrow();
    try {
      await link.start();
    } catch (_) {
      throw MeshUnavailableException();
    } finally {
      _snapshot(link);
    }
    // The link logs and returns when permission is refused or there is no
    // radio, rather than throwing, and a caller that only saw the Future
    // would think all was well.
    final phase = link.toMeshStatus().phase;
    if (phase == MeshPhase.unsupported || phase == MeshPhase.unauthorized) {
      throw MeshUnavailableException();
    }
    await _keepAlive.acquire();
  }

  Future<void> stop() async {
    final link = await _identityOrThrow();
    await _keepAlive.release();
    try {
      await link.stop();
    } catch (_) {
      throw MeshUnavailableException();
    } finally {
      _snapshot(link);
    }
  }

  /// What to do when the app comes back to the foreground.
  ///
  /// A radio that wanted to run but is not, because the adapter went away or
  /// the platform paused it, is asked to start again. Relays that dropped
  /// while the app was away reconnect now rather than at the end of their
  /// backoff. Neither failing is an error: the status streams already show
  /// the outcome, and the screen that asked has nothing else to do about it.
  Future<void> resume() async {
    final link = await _identityOrThrow();
    if (link.wantRunning && !link.running) {
      try {
        await link.start();
      } catch (_) {
        // Reported through the status stream.
      } finally {
        _snapshot(link);
      }
    }
    if (_bridge != null) {
      try {
        (await _relays).nudge();
      } catch (_) {
        // A pool that never came up has nothing to nudge.
      }
    }
  }

  /// Floods [text] to everyone in range, in the clear.
  Future<void> sendText(String text) async {
    final link = await _running();
    try {
      await link.send(text);
    } catch (_) {
      throw MeshSendException();
    }
  }

  /// Sends [text] to [peerId] inside a Noise session, handshaking first if
  /// there is none, and holding it in the outbox if the peer is out of reach.
  Future<void> sendSealedText({
    required String peerId,
    required String text,
  }) async {
    final link = await _running();
    try {
      await link.sendSealed(peerId, text);
    } catch (_) {
      throw MeshSendException();
    }
  }

  /// Opens the relay path, so peers met on the mesh can be reached when the
  /// radio cannot. Safe to call twice.
  Future<void> startRelays() async {
    if (_bridge != null) return;
    final link = await _identityOrThrow();
    try {
      // The Nostr key is the third thing derived from the seed the radio
      // already loaded. Nothing extra to store or unlock.
      final nostr = await NostrIdentity.fromSeed(link.identity.seed);
      final relays = await _relays;
      relays.open();
      final bridge = NostrBridge(identity: nostr, client: relays);
      _bridge = bridge;
      link.nostrPublicKey = nostr.publicKeyHex;
      link.nostrSend = bridge.send;
      _inbound = bridge.inbound.listen(
        (m) => link.acceptFromNostr(m.bytes, fromPubkeyHex: m.fromPubkeyHex),
      );
      _relayChanges = bridge.client.connectionChanges.listen((up) {
        if (!_relayStatus.isClosed) _relayStatus.add(up.toRelayStatus());
      });
      _relayStatus.add(RelayStatus.connecting);
      bridge.start();
      link.note('nostr identity ${nostr.shortNpub}');
    } catch (_) {
      await stopRelays();
      throw RelayUnavailableException();
    }
  }

  Future<void> stopRelays() async {
    if (!_relayStatus.isClosed) _relayStatus.add(RelayStatus.stopped);
    // Nothing was wired if there is no bridge, and with no identity there is
    // no link to unwire from either.
    if (_bridge == null) return;
    final link = await _identityOrThrow();
    link.nostrSend = null;
    link.nostrPublicKey = null;
    await _inbound?.cancel();
    await _relayChanges?.cancel();
    _inbound = null;
    _relayChanges = null;
    final bridge = _bridge;
    _bridge = null;
    await bridge?.close();
  }

  Future<MeshLink> _identityOrThrow() async {
    try {
      return await _link;
    } catch (_) {
      throw IdentityLoadException();
    }
  }

  Future<MeshLink> _running() async {
    final link = await _identityOrThrow();
    if (!link.running) throw MeshNotRunningException();
    return link;
  }

  Future<void> dispose() async {
    await _keepAlive.release();
    await _snapshots?.cancel();
    try {
      await stopRelays();
      await (await _relays).close();
      await (await _link).dispose();
    } catch (_) {
      // No identity means no link was ever built. Nothing to release.
    }
    await _peers.close();
    await _meshStatus.close();
    await _relayStatus.close();
  }
}
