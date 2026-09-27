import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:rxdart/rxdart.dart';

import 'bounty_local_storage.dart';
import 'mappers/mappers.dart';

/// Bounties, as seen from this device.
///
/// There is no server holding the truth. What this repository knows is the
/// union of what it posted, what floated in over the radio and what it kept
/// from last time, and a record is trusted exactly as far as its signature
/// carries it: the first record seen for an id pins the author's key, and
/// only that key can revise it afterwards.
///
/// Claims are private. They travel inside a Noise session as messages, and
/// the public record only changes when the author accepts somebody.
class BountyRepository {
  BountyRepository({
    required Future<MeshLink> link,
    required Future<RelayTransport> relays,
    required KeyValueStorage keyValueStorage,
    @visibleForTesting BountyLocalStorage? localStorage,
    @visibleForTesting DateTime Function()? clock,
    @visibleForTesting Random? random,
  }) : _link = link,
       _relays = relays,
       _storage =
           localStorage ?? BountyLocalStorage(keyValueStorage: keyValueStorage),
       _now = clock ?? DateTime.now,
       _random = random ?? Random.secure() {
    // As in MeshRepository: a failed identity is reported by whichever method
    // first needs the link, not as an unhandled error.
    _link.ignore();
    _relays.ignore();
    _link.then(_wire).catchError(_fail).ignore();
  }

  /// In UTF-8 bytes, matching the wire.
  static const maxTitleBytes = BountyRM.maxTitleBytes;
  static const maxDetailsBytes = BountyRM.maxDetailsBytes;
  static const maxNoteBytes = BountyMessageRM.maxNoteBytes;

  /// How often the same newcomer gets the same records again.
  static const gossipPerPeerCooldown = Duration(minutes: 1);

  /// The least time between two gossip bursts, whoever arrived.
  static const gossipGlobalGap = Duration(seconds: 20);

  /// Newest first, and no more than this per burst. A phone that walks into
  /// a room of forty bounties does not need all forty in one second.
  static const gossipBatch = 20;

  static const _expiryTick = Duration(minutes: 1);

  /// How often my own open bounties go out again while anyone is in range.
  ///
  /// A flood is one shot: a post made during a two second link drop reaches
  /// nobody and nothing brings it back until a new peer shows up. Repeating
  /// my own open records on a slow cadence costs a few hundred bytes a
  /// minute and makes the board converge without anyone having to leave and
  /// come back.
  static const republishEvery = Duration(minutes: 2);

  final Future<MeshLink> _link;
  final Future<RelayTransport> _relays;
  final BountyLocalStorage _storage;
  NostrBoard? _board;
  String? _area;

  /// Our Nostr identity, derived once from the seed the radio holds.
  Future<NostrIdentity>? _nostr;

  Future<NostrIdentity> _nostrIdentity(MeshLink link) =>
      _nostr ??= NostrIdentity.fromSeed(link.identity.seed);
  final DateTime Function() _now;
  final Random _random;

  final _bounties = BehaviorSubject<List<Bounty>>.seeded(const []);
  final _claims = BehaviorSubject<List<Claim>>.seeded(const []);
  final _witnesses = BehaviorSubject<List<Witness>>.seeded(const []);
  final _cacheFailures = PublishSubject<BountyCacheException>();

  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _expiry;
  Timer? _republish;
  final Set<String> _seenPeers = {};
  final Map<String, DateTime> _lastGossipTo = {};
  DateTime? _lastGossipAt;

  /// Everything known that is still worth showing: open bounties that have
  /// not expired, plus anything this device posted or claimed regardless of
  /// age, so a history survives its own deadlines. Newest first.
  Stream<List<Bounty>> getBounties() =>
      _bounties.stream.distinct(const ListEquality<Bounty>().equals);

  /// Claims on my bounties, and my claims on other people's.
  Stream<List<Claim>> getClaims() =>
      _claims.stream.distinct(const ListEquality<Claim>().equals);

  /// Everyone who co-signed a completion they heard on the radio. Newest
  /// first. Standalone records, not a field on the bounty.
  Stream<List<Witness>> getWitnesses() =>
      _witnesses.stream.distinct(const ListEquality<Witness>().equals);

  /// Follows listings on the internet around [area], so bounties posted
  /// further than a radio can reach still show, marked as such. Coarsened
  /// to a city-sized cell first; nobody needs to know the block.
  Future<void> followArea(Geohash area) async {
    _area = area.truncate(Geohash.areaPrecision).value;
    _board?.follow(_area!);
  }

  /// Every time the cache underneath the lists failed.
  ///
  /// Its own stream, not an error on the lists. A BehaviorSubject replays
  /// its last event to every new listener, and when that event was an error
  /// every screen opened afterwards started with a failure it never caused.
  Stream<BountyCacheException> get cacheFailures => _cacheFailures.stream;

  // ---------------------------------------------------------------- wiring

  Future<void> _wire(MeshLink link) async {
    await _emit(link);
    // One at a time, in arrival order. Two echoes of the same record in one
    // tick would otherwise both pass the "is this newer" check before either
    // had been written.
    _subs.add(
      link.bountyRecords
          .asyncMap((bytes) => _guarded(() => _onRecord(link, bytes)))
          .listen(null),
    );
    _subs.add(
      link.bountyMessages
          .asyncMap((m) => _guarded(() => _onMessage(link, m)))
          .listen(null),
    );
    _subs.add(
      link.witnessRequests
          .asyncMap((r) => _guarded(() => _onWitnessRequest(link, r)))
          .listen(null),
    );
    _subs.add(
      link.witnessRecords
          .asyncMap((w) => _guarded(() => _onWitness(link, w)))
          .listen(null),
    );
    // The link has no peers stream, only getters, and nothing about a peer
    // changes without a log line. Same trick as MeshRepository.
    _subs.add(
      link.logs
          .throttleTime(const Duration(milliseconds: 300), trailing: true)
          .listen((_) => _onPeersMaybeChanged(link)),
    );
    _expiry = Timer.periodic(_expiryTick, (_) => _guarded(() => _emit(link)));
    _republish = Timer.periodic(
      republishEvery,
      (_) => _guarded(() => _republishOwn(link)),
    );
    _startBoard(link).ignore();
  }

  /// The internet side of the board, once the relays exist. Records that
  /// arrive this way go through exactly the same checks as radio ones and
  /// are only marked as internet-borne until the radio confirms them.
  Future<void> _startBoard(MeshLink link) async {
    try {
      final relays = await _relays;
      final nostr = await _nostrIdentity(link);
      final board = NostrBoard(identity: nostr, client: relays)..start();
      _board = board;
      _subs.add(
        board.records
            .asyncMap(
              (bytes) =>
                  _guarded(() => _onRecord(link, bytes, viaInternet: true)),
            )
            .listen(null),
      );
      final area = _area;
      if (area != null) board.follow(area);
    } catch (_) {
      // No relays, no internet side. The radio does not care.
    }
  }

  /// What to do when the app comes back to the foreground: everything the
  /// two minute tick would do, now. Anything that happened while the app
  /// was away has waited long enough.
  Future<void> resume() async {
    final link = await _identityOrThrow();
    await _guarded(() => _republishOwn(link));
  }

  /// Renews my own open, unexpired bounties, if anyone can hear, and
  /// repeats unanswered claims to authors that can still be reached.
  ///
  /// A renewal is a fresh revision, same content, new updatedAt, new
  /// signature. That timestamp is the only proof anyone has that the key
  /// behind a bounty is still alive: a phone that is lost, wiped or dead
  /// stops renewing, and after [Bounty.posterLease] without one every other
  /// phone shows the bounty as unattended. Resending the old bytes would
  /// say nothing, since everyone already has them.
  Future<void> _republishOwn(MeshLink link) async {
    final radio = link.running && link.neighbours.isNotEmpty;
    final internet = _board != null && await _relaysUp();
    if (!radio && !internet) {
      await _resendPendingClaims(link);
      return;
    }
    final me = link.identity.peerId;
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final mine = (await _storage.getBounties())
        .where((b) => b.authorPeerId == me)
        .where((b) => b.status == BountyRM.statusOpen)
        .where((b) => b.expiresAt > nowSeconds);
    for (final cm in mine) {
      final current = BountyRM.decode(cm.record);
      if (current == null) continue;
      final renewed = await current.revise(
        signingKeyPair: link.identity.signingKeyPair,
        updatedAt: max(nowSeconds, current.updatedAt + 1),
      );
      final bytes = renewed.encode();
      await _storage.upsertBounty(renewed.toCacheModel(record: bytes));
      if (radio) {
        try {
          await link.publishBounty(bytes);
        } catch (_) {
          // Next tick.
        }
      }
      if (internet) _board?.publish(renewed).ignore();
    }
    await _resendPendingClaims(link);
  }

  Future<bool> _relaysUp() async {
    try {
      return (await _relays).isConnected;
    } catch (_) {
      return false;
    }
  }

  /// Says "I would like to do this" again for every claim of mine the author
  /// has not answered, if the author can be reached, by radio or internet.
  ///
  /// A claim is one sealed message, and one sealed message can be lost. The
  /// author records a repeated claim as the same claim, so repeating it costs
  /// nothing but a few bytes and turns a lost offer into a late one.
  Future<void> _resendPendingClaims(MeshLink link) async {
    final me = link.identity.peerId;
    for (final claim in await _storage.getClaims()) {
      if (claim.claimantPeerId != me) continue;
      if (claim.status != ClaimCM.statusPending) continue;
      // Delivered once is delivered. Repeating it would only make the
      // poster's phone answer again.
      if (claim.receivedAt != null) continue;
      final bounty = await _storage.getBounty(claim.bountyId);
      if (bounty == null || bounty.status != BountyRM.statusOpen) continue;
      if (!link.canReach(bounty.authorPeerId)) continue;
      try {
        await link.sendBountyMessage(
          bounty.authorPeerId,
          BountyMessageRM(
            kind: BountyMessageRM.kindClaim,
            bountyId: claim.bountyId,
            sentAt: claim.sentAt,
            note: claim.note,
          ).encode(),
        );
      } catch (_) {
        // Next tick.
      }
    }
  }

  /// Storage trouble on the reactive path becomes an error on the streams,
  /// where a screen can show it, rather than an unhandled one in a zone.
  Future<void> _guarded(Future<void> Function() op) async {
    try {
      await op();
    } on BountyCacheException catch (e, st) {
      _fail(e, st);
    }
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    // An identity that never loaded already surfaces from every method; the
    // streams only need to know when the cache itself is broken.
    if (error is! BountyCacheException) return;
    if (!_cacheFailures.isClosed) _cacheFailures.add(error);
  }

  Future<void> _emit(MeshLink link) async {
    if (_bounties.isClosed) return;
    final me = link.identity.peerId;
    final now = _now();
    final claims = await _storage.getClaims();
    final myClaimed = {
      for (final c in claims)
        if (c.claimantPeerId == me) c.bountyId,
    };
    final witnesses = [
      for (final cm in await _storage.getWitnesses())
        cm.toDomainModel(myPeerId: me),
    ];
    witnesses.sort((a, b) => b.at.compareTo(a.at));
    // Labels per bounty, in the same newest-first order, so a screen can show
    // who vouched without holding the records.
    final labelsFor = <String, List<String>>{};
    for (final w in witnesses) {
      (labelsFor[w.bountyId] ??= []).add(w.witnessLabel);
    }

    final bounties = <Bounty>[];
    for (final cm in await _storage.getBounties()) {
      final Bounty bounty;
      try {
        bounty = cm.toDomainModel(
          myPeerId: me,
          witnessLabels: labelsFor[cm.id] ?? const [],
        );
      } on FormatException {
        continue; // a status this build does not know
      }
      // Expired and lapsed leave the same way: quietly, unless it is mine or
      // I have a claim on it, in which case it stays until I deal with it.
      final keep =
          bounty.isMine ||
          myClaimed.contains(bounty.id) ||
          (!bounty.isExpiredAt(now) && !bounty.isLapsedAt(now));
      if (keep) bounties.add(bounty);
    }
    bounties.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final domainClaims = <Claim>[];
    for (final cm in claims) {
      try {
        domainClaims.add(cm.toDomainModel(myPeerId: me));
      } on FormatException {
        continue;
      }
    }
    domainClaims.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    if (_bounties.isClosed) return;
    _bounties.add(bounties);
    _claims.add(domainClaims);
    if (!_witnesses.isClosed) _witnesses.add(witnesses);
  }

  // --------------------------------------------------------------- inbound

  Future<void> _onRecord(
    MeshLink link,
    Uint8List bytes, {
    bool viaInternet = false,
  }) async {
    final rm = BountyRM.decode(bytes);
    if (rm == null) return;
    if (!await rm.verify()) {
      link.note('bounty ${rm.id.substring(0, 6)} failed verification');
      return;
    }
    try {
      rm.status.toBountyStatus();
    } on FormatException {
      return;
    }
    final known = await _storage.getBounty(rm.id);
    if (known != null) {
      // Pinned on first sight. A different key or author naming the same id
      // is somebody else's record wearing this one's name.
      if (known.authorPeerId != rm.authorPeerId ||
          !const ListEquality<int>().equals(
            known.authorSigningKey,
            rm.authorSigningKey,
          )) {
        link.note('bounty ${rm.id.substring(0, 6)} revised by a stranger');
        return;
      }
      // Gossip echoes the same revision many times over. But an echo from
      // the radio of something we only had from the internet is news: the
      // poster is within reach after all.
      if (rm.updatedAt <= known.updatedAt) {
        if (!viaInternet && known.viaInternet) {
          await _storage.upsertBounty(
            BountyRM.decode(
              known.record,
            )!.toCacheModel(record: known.record, viaInternet: false),
          );
          await _emit(link);
        }
        return;
      }
    }
    await _storage.upsertBounty(
      rm.toCacheModel(
        record: bytes,
        viaInternet: viaInternet && (known == null || known.viaInternet),
      ),
    );
    // The record says where its author can be reached over the internet,
    // signed by the author, so a claim on a bounty seen only over relays
    // has somewhere to go before the phones have ever met.
    if (rm.authorNostrKey.isNotEmpty) {
      link.learnNostrAddress(rm.authorPeerId, rm.authorNostrKeyHex);
    }
    await _reflectRecordOnClaims(link, rm);
    await _emit(link);
  }

  /// A public revision tells a claimant where they stand without a private
  /// message having to arrive first.
  Future<void> _reflectRecordOnClaims(MeshLink link, BountyRM rm) async {
    final me = link.identity.peerId;
    final mine = await _storage.getClaim(rm.id, me);
    if (mine == null) return;
    final int? next;
    if (rm.status == BountyRM.statusClaimed) {
      next = rm.claimantPeerId == me
          ? ClaimCM.statusAccepted
          : ClaimCM.statusDeclined;
    } else if ((rm.status == BountyRM.statusDone ||
            rm.status == BountyRM.statusPaid) &&
        rm.claimantPeerId == me) {
      next = ClaimCM.statusDone;
    } else if (rm.status == BountyRM.statusCancelled &&
        mine.status == ClaimCM.statusPending) {
      next = ClaimCM.statusDeclined;
    } else {
      next = null;
    }
    if (next != null && next != mine.status) {
      await _storage.upsertClaim(_withStatus(mine, next));
    }
  }

  Future<void> _onMessage(
    MeshLink link,
    ({String from, Uint8List body}) message,
  ) async {
    final rm = BountyMessageRM.decode(message.body);
    if (rm == null) return;
    final me = link.identity.peerId;
    final bounty = await _storage.getBounty(rm.bountyId);
    if (bounty == null) return;
    final from = message.from;

    switch (rm.kind) {
      case BountyMessageRM.kindClaim:
        // Only the author collects claims, and only while there is something
        // to claim.
        if (bounty.authorPeerId != me) return;
        if (bounty.status != BountyRM.statusOpen) return;
        if (from == me) return;
        await _storage.upsertClaim(rm.toClaimCacheModel(from: from));
        // Delivered, not decided. The claimant is looking at a spinner and
        // deserves to know the difference between a poster who is thinking
        // and a phone that is off.
        try {
          await _send(
            link,
            from,
            _reply(BountyMessageRM.kindReceived, rm.bountyId),
          );
        } on BountySendException {
          // The next repeat of their claim gets another chance.
        }
      case BountyMessageRM.kindReceived:
        if (from != bounty.authorPeerId) return;
        final mine = await _storage.getClaim(rm.bountyId, me);
        if (mine == null || mine.receivedAt != null) return;
        await _storage.upsertClaim(_received(mine, rm.sentAt));
      case BountyMessageRM.kindWithdraw:
        if (bounty.authorPeerId != me) return;
        final theirs = await _storage.getClaim(rm.bountyId, from);
        if (theirs == null) return;
        await _storage.deleteClaim(rm.bountyId, from);
        // If they were the one doing it, the bounty is open again. Only my
        // key can say so, which is why this happens here and not on their
        // phone.
        if (bounty.status == BountyRM.statusClaimed &&
            bounty.claimantPeerId == from) {
          try {
            await _revise(
              link,
              bounty,
              status: BountyRM.statusOpen,
              clearClaimant: true,
            );
          } on BountySendException {
            // Stored locally either way; the next renewal carries it.
          }
        }
      case BountyMessageRM.kindAccept:
      case BountyMessageRM.kindDecline:
        if (from != bounty.authorPeerId) return;
        final mine = await _storage.getClaim(rm.bountyId, me);
        if (mine == null) return;
        await _storage.upsertClaim(
          _withStatus(
            mine,
            rm.kind == BountyMessageRM.kindAccept
                ? ClaimCM.statusAccepted
                : ClaimCM.statusDeclined,
          ),
        );
      case BountyMessageRM.kindDone:
        if (bounty.authorPeerId != me) return;
        final theirs = await _storage.getClaim(rm.bountyId, from);
        if (theirs == null) return;
        await _storage.upsertClaim(_withStatus(theirs, ClaimCM.statusDone));
      default:
        return;
    }
    await _emit(link);
  }

  // ---------------------------------------------------------------- gossip

  /// Re-floods what we know to whoever just showed up.
  ///
  /// This is what makes the mesh a notice board rather than a shout: a phone
  /// that arrives an hour after a bounty was posted still sees it, because
  /// somebody who heard it is still in the room. Records are forwarded as
  /// received; the signature inside is what makes that safe.
  Future<void> _onPeersMaybeChanged(MeshLink link) => _guarded(() async {
    // Live links, not addressable peers: a session outlives its link by
    // ten minutes, so on that basis a phone that dropped and came back
    // never counted as new and never got anything.
    final current = link.neighbours;
    final newcomers = current.difference(_seenPeers);
    _seenPeers
      ..clear()
      ..addAll(current);
    if (newcomers.isEmpty) return;

    final now = _now();
    final due = newcomers.where((p) {
      final last = _lastGossipTo[p];
      return last == null || now.difference(last) >= gossipPerPeerCooldown;
    }).toList();
    if (due.isEmpty) return;
    final lastBurst = _lastGossipAt;
    if (lastBurst != null && now.difference(lastBurst) < gossipGlobalGap) {
      return;
    }
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final open =
        (await _storage.getBounties())
            .where((b) => b.status == BountyRM.statusOpen)
            .where((b) => b.expiresAt > nowSeconds)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // A burst with nothing in it does not count as a burst. Otherwise a
    // peer that arrived before anything was posted sat out the whole
    // cooldown without ever having been sent a thing, which is how a
    // bounty posted while the other phone was restarting went unheard.
    if (open.isEmpty) return;
    for (final p in due) {
      _lastGossipTo[p] = now;
    }
    _lastGossipAt = now;

    for (final cm in open.take(gossipBatch)) {
      try {
        await link.publishBounty(cm.record);
      } catch (_) {
        // The radio will be there next time. Nothing to tell a user.
      }
    }
  });

  // --------------------------------------------------------------- actions

  /// Posts a new bounty from this device and floods it.
  Future<Bounty> postBounty({
    required String title,
    required String details,
    required int amountCents,
    required DateTime expiresAt,
    Geohash? geohash,
  }) async {
    final link = await _running();
    final now = _now();
    final cleanTitle = title.trim();
    final cleanDetails = details.trim();
    if (cleanTitle.isEmpty ||
        utf8.encode(cleanTitle).length > maxTitleBytes ||
        utf8.encode(cleanDetails).length > maxDetailsBytes ||
        amountCents <= 0 ||
        amountCents > 0xFFFFFFFF ||
        !expiresAt.isAfter(now)) {
      throw BountyValidationException();
    }

    final identity = link.identity;
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final rm = await BountyRM.sign(
      id: _newId(),
      authorPeerId: identity.peerId,
      signingKeyPair: identity.signingKeyPair,
      signingPublicKey: identity.signingPublicKey,
      nostrPublicKey: _hexToBytes((await _nostrIdentity(link)).publicKeyHex),
      createdAt: nowSeconds,
      expiresAt: expiresAt.millisecondsSinceEpoch ~/ 1000,
      updatedAt: nowSeconds,
      amountCents: amountCents,
      status: BountyRM.statusOpen,
      claimantPeerId: null,
      title: cleanTitle,
      details: cleanDetails,
      geohash: geohash?.value ?? '',
    );
    final bytes = rm.encode();
    await _publish(link, bytes);
    final cm = rm.toCacheModel(record: bytes);
    await _storage.upsertBounty(cm);
    await _emit(link);
    return cm.toDomainModel(myPeerId: identity.peerId);
  }

  /// Offers to do somebody else's bounty. Private to its author.
  Future<void> claim(String bountyId, {String note = ''}) async {
    final link = await _running();
    final me = link.identity.peerId;
    final cm = await _bountyOrThrow(bountyId);
    if (cm.authorPeerId == me) throw CannotClaimOwnBountyException();
    final cleanNote = note.trim();
    if (utf8.encode(cleanNote).length > maxNoteBytes) {
      throw BountyValidationException();
    }
    final now = _now();
    if (cm.status != BountyRM.statusOpen ||
        cm.expiresAt <= now.millisecondsSinceEpoch ~/ 1000) {
      throw BountyClosedException();
    }
    final sentAt = now.millisecondsSinceEpoch ~/ 1000;
    await _send(
      link,
      cm.authorPeerId,
      BountyMessageRM(
        kind: BountyMessageRM.kindClaim,
        bountyId: bountyId,
        sentAt: sentAt,
        note: cleanNote,
      ),
    );
    await _storage.upsertClaim(
      ClaimCM(
        bountyId: bountyId,
        claimantPeerId: me,
        note: cleanNote,
        sentAt: sentAt,
        status: ClaimCM.statusPending,
      ),
    );
    await _emit(link);
  }

  /// Picks [claimantId] to do my bounty. Everyone else who asked is told no.
  Future<void> accept(String bountyId, String claimantId) async {
    final link = await _running();
    final cm = await _mineOrThrow(link, bountyId);
    if (cm.status != BountyRM.statusOpen) throw BountyClosedException();
    final claim = await _storage.getClaim(bountyId, claimantId);
    if (claim == null) throw BountyNotFoundException();

    await _revise(
      link,
      cm,
      status: BountyRM.statusClaimed,
      claimantPeerId: claimantId,
    );
    await _storage.upsertClaim(_withStatus(claim, ClaimCM.statusAccepted));
    await _send(link, claimantId, _reply(BountyMessageRM.kindAccept, bountyId));

    for (final other in await _storage.getClaims()) {
      if (other.bountyId != bountyId || other.claimantPeerId == claimantId) {
        continue;
      }
      if (other.status != ClaimCM.statusPending) continue;
      await _storage.upsertClaim(_withStatus(other, ClaimCM.statusDeclined));
      await _send(
        link,
        other.claimantPeerId,
        _reply(BountyMessageRM.kindDecline, bountyId),
      );
    }
    await _emit(link);
  }

  Future<void> decline(String bountyId, String claimantId) async {
    final link = await _running();
    await _mineOrThrow(link, bountyId);
    final claim = await _storage.getClaim(bountyId, claimantId);
    if (claim == null) throw BountyNotFoundException();
    await _storage.upsertClaim(_withStatus(claim, ClaimCM.statusDeclined));
    await _send(
      link,
      claimantId,
      _reply(BountyMessageRM.kindDecline, bountyId),
    );
    await _emit(link);
  }

  /// As the author: confirms the work is done, publicly. As the accepted
  /// claimant: tells the author it is, privately.
  Future<void> markDone(String bountyId) async {
    final link = await _running();
    final me = link.identity.peerId;
    final cm = await _bountyOrThrow(bountyId);
    if (cm.authorPeerId == me) {
      if (cm.status != BountyRM.statusClaimed) throw BountyClosedException();
      await _revise(link, cm, status: BountyRM.statusDone);
      final claim = await _storage.getClaim(bountyId, cm.claimantPeerId ?? '');
      if (claim != null) {
        await _storage.upsertClaim(_withStatus(claim, ClaimCM.statusDone));
      }
    } else {
      final mine = await _storage.getClaim(bountyId, me);
      if (mine == null || mine.status != ClaimCM.statusAccepted) {
        throw NotBountyAuthorException();
      }
      await _send(
        link,
        cm.authorPeerId,
        _reply(BountyMessageRM.kindDone, bountyId),
      );
      await _storage.upsertClaim(_withStatus(mine, ClaimCM.statusDone));
      // Ask the room to co-sign it. Swallowed on purpose: the completion has
      // already gone to the poster and is recorded here, and a radio that
      // would not take one more frame must not undo either of those.
      try {
        await link.requestWitnesses(bountyId, me);
      } catch (_) {
        link.note('witness request for ${bountyId.substring(0, 6)} not sent');
      }
    }
    await _emit(link);
  }

  /// Asks again for witnesses to a completion this device claimed.
  ///
  /// [markDone] already does this once. A second ask costs one frame and
  /// catches the phones that were not in the room the first time.
  Future<void> requestWitnesses(String bountyId) async {
    final link = await _running();
    final me = link.identity.peerId;
    final cm = await _bountyOrThrow(bountyId);
    if (cm.claimantPeerId != me) throw NotBountyClaimantException();
    try {
      await link.requestWitnesses(bountyId, me);
    } catch (_) {
      throw BountySendException();
    }
  }

  /// The author says the money changed hands.
  Future<void> markPaid(String bountyId) async {
    final link = await _running();
    final cm = await _mineOrThrow(link, bountyId);
    if (cm.status != BountyRM.statusDone &&
        cm.status != BountyRM.statusClaimed) {
      throw BountyClosedException();
    }
    await _revise(link, cm, status: BountyRM.statusPaid);
    await _emit(link);
  }

  Future<void> cancel(String bountyId) async {
    final link = await _running();
    final cm = await _mineOrThrow(link, bountyId);
    if (cm.status != BountyRM.statusOpen &&
        cm.status != BountyRM.statusClaimed) {
      throw BountyClosedException();
    }
    await _revise(link, cm, status: BountyRM.statusCancelled);
    await _emit(link);
  }

  // ------------------------------------------------------------ retirement

  /// What forgetting this identity would leave behind, right now.
  Future<RetirementOutlook> retirementOutlook() async {
    final link = await _identityOrThrow();
    final me = link.identity.peerId;
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final live = (await _storage.getBounties())
        .where((b) => b.expiresAt > nowSeconds)
        .toList();
    final mine = live
        .where((b) => b.authorPeerId == me)
        .where(
          (b) =>
              b.status == BountyRM.statusOpen ||
              b.status == BountyRM.statusClaimed,
        )
        .toList();
    final liveIds = {for (final b in live) b.id};
    final pending = (await _storage.getClaims())
        .where((c) => c.claimantPeerId == me)
        .where(
          (c) =>
              c.status == ClaimCM.statusPending ||
              c.status == ClaimCM.statusAccepted,
        )
        .where((c) => liveIds.contains(c.bountyId))
        .length;
    return RetirementOutlook(
      openBountyTitles: [
        for (final b in mine) BountyRM.decode(b.record)?.title ?? '',
      ],
      pendingClaimCount: pending,
      canAnnounce: await _canAnnounce(link),
    );
  }

  /// Closes everything this identity has open, while it still has the key
  /// to do so: every bounty of mine still open or claimed is cancelled and
  /// its listing retracted, every claim of mine still standing is
  /// withdrawn. Best effort on whatever path is up. The caller erases the
  /// seed afterwards; nothing here does.
  ///
  /// [flush] gives the last frames a moment to leave before the caller
  /// tears the transports down.
  Future<void> retireIdentity({
    Duration flush = const Duration(seconds: 1),
  }) async {
    final link = await _identityOrThrow();
    final me = link.identity.peerId;
    final radio = link.running && link.neighbours.isNotEmpty;
    final internet = _board != null && await _relaysUp();
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;

    for (final cm in await _storage.getBounties()) {
      if (cm.authorPeerId != me) continue;
      if (cm.status != BountyRM.statusOpen &&
          cm.status != BountyRM.statusClaimed) {
        continue;
      }
      final current = BountyRM.decode(cm.record);
      if (current == null) continue;
      final cancelled = await current.revise(
        signingKeyPair: link.identity.signingKeyPair,
        updatedAt: max(nowSeconds, current.updatedAt + 1),
        status: BountyRM.statusCancelled,
      );
      final bytes = cancelled.encode();
      await _storage.upsertBounty(cancelled.toCacheModel(record: bytes));
      if (radio) {
        try {
          await link.publishBounty(bytes);
        } catch (_) {
          // Nothing more to try on this path.
        }
      }
      if (internet) {
        await _board?.publish(cancelled);
        await _board?.retract(cancelled);
      }
    }

    for (final claim in await _storage.getClaims()) {
      if (claim.claimantPeerId != me) continue;
      if (claim.status != ClaimCM.statusPending &&
          claim.status != ClaimCM.statusAccepted) {
        continue;
      }
      final bounty = await _storage.getBounty(claim.bountyId);
      if (bounty == null || bounty.expiresAt <= nowSeconds) continue;
      if (!link.canReach(bounty.authorPeerId)) continue;
      try {
        await _send(
          link,
          bounty.authorPeerId,
          _reply(BountyMessageRM.kindWithdraw, claim.bountyId),
        );
      } on BountySendException {
        // Held in the outbox, which dies with the identity. Reported to the
        // user beforehand by retirementOutlook, which is the honest part.
      }
    }
    await _emit(link);
    if (flush > Duration.zero) await Future<void>.delayed(flush);
  }

  Future<bool> _canAnnounce(MeshLink link) async =>
      (link.running && link.neighbours.isNotEmpty) ||
      (_board != null && await _relaysUp());

  // --------------------------------------------------------------- helpers

  Future<void> _revise(
    MeshLink link,
    BountyCM cm, {
    required int status,
    String? claimantPeerId,
    bool clearClaimant = false,
  }) async {
    final current = BountyRM.decode(cm.record);
    if (current == null) throw BountyNotFoundException();
    final nowSeconds = _now().millisecondsSinceEpoch ~/ 1000;
    final revised = await current.revise(
      signingKeyPair: link.identity.signingKeyPair,
      // Strictly newer, even on a clock that has not moved, or the revision
      // would be ignored as an echo by everyone including ourselves.
      updatedAt: max(nowSeconds, current.updatedAt + 1),
      status: status,
      claimantPeerId: claimantPeerId,
      clearClaimant: clearClaimant,
    );
    final bytes = revised.encode();
    await _publish(link, bytes);
    await _storage.upsertBounty(revised.toCacheModel(record: bytes));
  }

  Future<void> _publish(MeshLink link, Uint8List bytes) async {
    try {
      await link.publishBounty(bytes);
    } catch (_) {
      throw BountySendException();
    }
    // The listing is a bonus. A relay being down costs nothing here.
    final rm = BountyRM.decode(bytes);
    if (rm != null) _board?.publish(rm).ignore();
  }

  /// Somebody in radio range says they finished a bounty. Decide whether to
  /// put our name to it.
  ///
  /// That the request came over the radio is not checked here and cannot be:
  /// MeshLink drops internet-borne requests before this stream, which is the
  /// whole of the rule. Everything below is about whether we are a witness
  /// worth having.
  Future<void> _onWitnessRequest(MeshLink link, WitnessRequest request) async {
    final me = link.identity.peerId;
    // Nobody vouches for themselves.
    if (request.claimantPeerId == me) return;
    // Only a phone that already holds the record can say what it is
    // witnessing. Without it we would be signing a bounty id and nothing more.
    final bounty = await _storage.getBounty(request.bountyId);
    if (bounty == null) return;
    // The poster is not an independent witness to their own bounty.
    if (bounty.authorPeerId == me) return;
    // A request naming somebody the author never accepted is noise.
    if (bounty.claimantPeerId != null &&
        bounty.claimantPeerId != request.claimantPeerId) {
      return;
    }
    // At most once per bounty, whatever happens below.
    if (await _storage.getWitness(request.bountyId, me) != null) return;

    final identity = link.identity;
    final rm = await WitnessRM.sign(
      bountyId: request.bountyId,
      claimantPeerId: request.claimantPeerId,
      witnessPeerId: me,
      signingKeyPair: identity.signingKeyPair,
      signingPublicKey: identity.signingPublicKey,
      noisePublicKey: identity.noisePublicKey,
      at: _now().millisecondsSinceEpoch ~/ 1000,
    );
    final bytes = rm.encode();
    // Stored before it is sent, on purpose. A radio that refuses the record
    // must not leave us free to sign a second one for the same bounty.
    await _storage.upsertWitness(rm.toCacheModel(record: bytes, mine: true));
    await _emit(link);
    try {
      await link.sendWitness(bounty.authorPeerId, bytes);
    } catch (_) {
      // The poster is out of reach. The outbox holds sealed messages for a
      // peer that comes back, and a witness nobody collected is not an error
      // anybody can act on.
      link.note('witness for ${request.bountyId.substring(0, 6)} not sent');
    }
  }

  /// A signed witness arrived, sealed, from somebody who heard a completion.
  ///
  /// Every refusal below is silent: these records come off the radio from
  /// anyone at all, and a bad one is not news, it is Tuesday.
  Future<void> _onWitness(
    MeshLink link,
    ({String from, Uint8List body}) message,
  ) async {
    final rm = WitnessRM.decode(message.body);
    if (rm == null) return;
    // Signature, and the peer id against the noise key it claims.
    if (!await rm.verify()) {
      link.note('witness for ${rm.bountyId.substring(0, 6)} failed to verify');
      return;
    }
    // The record says who signed it; the session says who sent it. A record
    // relayed by somebody other than its signer is not evidence of anything.
    if (rm.witnessPeerId != message.from) return;
    final bounty = await _storage.getBounty(rm.bountyId);
    if (bounty == null) return;
    // Only the poster collects. Anyone else holding these has no use for them
    // and no way to know the set is complete.
    if (bounty.authorPeerId != link.identity.peerId) return;
    // Neither party to the bounty is a witness to it.
    if (rm.witnessPeerId == bounty.authorPeerId) return;
    if (rm.witnessPeerId == rm.claimantPeerId) return;
    if (bounty.claimantPeerId != null &&
        rm.claimantPeerId != bounty.claimantPeerId) {
      return;
    }
    // One witness, one signature, however many times it arrives.
    if (await _storage.getWitness(rm.bountyId, rm.witnessPeerId) != null) {
      return;
    }
    await _storage.upsertWitness(rm.toCacheModel(record: message.body));
    await _emit(link);
  }

  Future<void> _send(MeshLink link, String peer, BountyMessageRM rm) async {
    try {
      await link.sendBountyMessage(peer, rm.encode());
    } catch (_) {
      throw BountySendException();
    }
  }

  BountyMessageRM _reply(int kind, String bountyId) => BountyMessageRM(
    kind: kind,
    bountyId: bountyId,
    sentAt: _now().millisecondsSinceEpoch ~/ 1000,
    note: '',
  );

  ClaimCM _withStatus(ClaimCM claim, int status) => ClaimCM(
    bountyId: claim.bountyId,
    claimantPeerId: claim.claimantPeerId,
    note: claim.note,
    sentAt: claim.sentAt,
    status: status,
    receivedAt: claim.receivedAt,
  );

  ClaimCM _received(ClaimCM claim, int at) => ClaimCM(
    bountyId: claim.bountyId,
    claimantPeerId: claim.claimantPeerId,
    note: claim.note,
    sentAt: claim.sentAt,
    status: claim.status,
    receivedAt: at,
  );

  Future<BountyCM> _bountyOrThrow(String id) async {
    final cm = await _storage.getBounty(id);
    if (cm == null) throw BountyNotFoundException();
    return cm;
  }

  Future<BountyCM> _mineOrThrow(MeshLink link, String id) async {
    final cm = await _bountyOrThrow(id);
    if (cm.authorPeerId != link.identity.peerId) {
      throw NotBountyAuthorException();
    }
    return cm;
  }

  static Uint8List _hexToBytes(String hex) => Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);

  String _newId() {
    final out = StringBuffer();
    for (var i = 0; i < BountyRM.idLength; i++) {
      out.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }

  Future<MeshLink> _identityOrThrow() async {
    try {
      return await _link;
    } catch (_) {
      throw IdentityLoadException();
    }
  }

  /// The link, provided something can carry a frame: the radio, or the
  /// relays for a peer whose address we know. With neither there is nobody
  /// to talk to, and saying so beats a message that sits in the outbox.
  Future<MeshLink> _running() async {
    final link = await _identityOrThrow();
    if (link.running) return link;
    try {
      if ((await _relays).isConnected) return link;
    } catch (_) {
      // No relays either.
    }
    throw MeshNotRunningException();
  }

  Future<void> dispose() async {
    _expiry?.cancel();
    _republish?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _board?.close();
    await _bounties.close();
    await _claims.close();
    await _witnesses.close();
    await _cacheFailures.close();
  }
}
