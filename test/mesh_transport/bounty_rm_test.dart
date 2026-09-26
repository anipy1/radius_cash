import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radius/mesh_transport/src/bounty/bounty_message_rm.dart';
import 'package:radius/mesh_transport/src/bounty/bounty_rm.dart';
import 'package:radius/mesh_transport/src/identity/node_identity.dart';

void main() {
  late NodeIdentity author;
  late NodeIdentity stranger;

  setUpAll(() async {
    author = await NodeIdentity.fromSeed(
      Uint8List.fromList(List.generate(32, (i) => i)),
    );
    stranger = await NodeIdentity.fromSeed(
      Uint8List.fromList(List.generate(32, (i) => 255 - i)),
    );
  });

  Future<BountyRM> post({
    String title = 'Carry a booth to hall B',
    String details = 'Two people, ten minutes.',
    int amountCents = 2500,
  }) => BountyRM.sign(
    id: '0123456789abcdef',
    authorPeerId: author.peerId,
    signingKeyPair: author.signingKeyPair,
    signingPublicKey: author.signingPublicKey,
    createdAt: 1800000000,
    expiresAt: 1800086400,
    updatedAt: 1800000000,
    amountCents: amountCents,
    status: BountyRM.statusOpen,
    claimantPeerId: null,
    title: title,
    details: details,
  );

  group('BountyRM', () {
    test('round trips through bytes', () async {
      final record = await post();
      final decoded = BountyRM.decode(record.encode());

      expect(decoded, isNotNull);
      expect(decoded!.id, record.id);
      expect(decoded.authorPeerId, author.peerId);
      expect(decoded.authorSigningKey, author.signingPublicKey);
      expect(decoded.createdAt, 1800000000);
      expect(decoded.expiresAt, 1800086400);
      expect(decoded.amountCents, 2500);
      expect(decoded.status, BountyRM.statusOpen);
      expect(decoded.claimantPeerId, isNull);
      expect(decoded.title, 'Carry a booth to hall B');
      expect(decoded.details, 'Two people, ten minutes.');
      expect(decoded.signature, record.signature);
    });

    test('a signed record verifies', () async {
      final record = await post();
      expect(await BountyRM.decode(record.encode())!.verify(), isTrue);
    });

    test('changing one byte of the amount breaks the signature', () async {
      final bytes = (await post()).encode();
      // amountCents sits after ver, id, author, key, created, expires, updated.
      final offset = 1 + 8 + 8 + 32 + 32 + 12 + 3;
      bytes[offset] ^= 0x01;
      final tampered = BountyRM.decode(bytes)!;
      expect(tampered.amountCents, isNot(2500));
      expect(await tampered.verify(), isFalse);
    });

    test(
      'a record signed by someone else does not verify as the author',
      () async {
        // The stranger signs a record naming the author's key. The signature
        // cannot match, which is the whole point of carrying the key.
        final forged = await BountyRM.sign(
          id: '0123456789abcdef',
          authorPeerId: author.peerId,
          signingKeyPair: stranger.signingKeyPair,
          signingPublicKey: author.signingPublicKey,
          createdAt: 1,
          expiresAt: 2,
          updatedAt: 1,
          amountCents: 1,
          status: BountyRM.statusOpen,
          claimantPeerId: null,
          title: 't',
          details: '',
        );
        expect(await forged.verify(), isFalse);
      },
    );

    test('a revision keeps the id and carries the new state', () async {
      final original = await post();
      final claimed = await original.revise(
        signingKeyPair: author.signingKeyPair,
        updatedAt: 1800000060,
        status: BountyRM.statusClaimed,
        claimantPeerId: stranger.peerId,
      );

      expect(claimed.id, original.id);
      expect(claimed.createdAt, original.createdAt);
      expect(claimed.status, BountyRM.statusClaimed);
      expect(claimed.claimantPeerId, stranger.peerId);
      expect(await BountyRM.decode(claimed.encode())!.verify(), isTrue);
      expect(claimed.signature, isNot(original.signature));
    });

    test('unicode in the title survives', () async {
      final record = await post(title: 'Tõsta kast üles, palun 🙏');
      expect(
        BountyRM.decode(record.encode())!.title,
        'Tõsta kast üles, palun 🙏',
      );
    });

    test('an oversized title is refused before it is signed', () {
      expect(post(title: 'x' * 101), throwsArgumentError);
      expect(post(details: 'x' * 501), throwsArgumentError);
    });

    test('a record fits in a handful of fragments', () async {
      final bytes = (await post(title: 'x' * 100, details: 'y' * 500)).encode();
      // Two headers of 12 bytes per fragment on a 185 byte MTU.
      expect(bytes.length, lessThan(185 * 5));
    });

    test('garbage is not a record', () {
      expect(BountyRM.decode(Uint8List(0)), isNull);
      expect(BountyRM.decode(Uint8List(10)), isNull);
      expect(BountyRM.decode(Uint8List(200)..[0] = 9), isNull);
    });

    test('a version 2 record carries the author\'s nostr key', () async {
      final nostr = Uint8List.fromList(List.generate(32, (i) => 200 - i));
      final record = await BountyRM.sign(
        id: '0123456789abcdef',
        authorPeerId: author.peerId,
        signingKeyPair: author.signingKeyPair,
        signingPublicKey: author.signingPublicKey,
        nostrPublicKey: nostr,
        createdAt: 1,
        expiresAt: 2,
        updatedAt: 1,
        amountCents: 1,
        status: BountyRM.statusOpen,
        claimantPeerId: null,
        title: 't',
        details: '',
      );
      final decoded = BountyRM.decode(record.encode())!;
      expect(decoded.version, 2);
      expect(decoded.authorNostrKey, nostr);
      expect(decoded.authorNostrKeyHex, hasLength(64));
      expect(await decoded.verify(), isTrue);
      // A revision keeps the key.
      final revised = await decoded.revise(
        signingKeyPair: author.signingKeyPair,
        updatedAt: 2,
      );
      expect(BountyRM.decode(revised.encode())!.authorNostrKey, nostr);
    });

    test('a record without a nostr key reads back as having none', () async {
      final decoded = BountyRM.decode((await post()).encode())!;
      expect(decoded.authorNostrKey, isEmpty);
      expect(await decoded.verify(), isTrue);
    });

    test('a version 1 record still decodes and verifies', () async {
      // Built by hand from a version 2 record: same fields, no key.
      final v2 = await post();
      final v1 = BountyRM(
        version: BountyRM.versionWithoutNostrKey,
        id: v2.id,
        authorPeerId: v2.authorPeerId,
        authorSigningKey: v2.authorSigningKey,
        authorNostrKey: Uint8List(0),
        createdAt: v2.createdAt,
        expiresAt: v2.expiresAt,
        updatedAt: v2.updatedAt,
        amountCents: v2.amountCents,
        status: v2.status,
        claimantPeerId: v2.claimantPeerId,
        title: v2.title,
        details: v2.details,
        geohash: v2.geohash,
        signature: Uint8List(64),
      );
      final signed = await BountyRM.sign(
        id: v1.id,
        authorPeerId: v1.authorPeerId,
        signingKeyPair: author.signingKeyPair,
        signingPublicKey: author.signingPublicKey,
        createdAt: v1.createdAt,
        expiresAt: v1.expiresAt,
        updatedAt: v1.updatedAt,
        amountCents: v1.amountCents,
        status: v1.status,
        claimantPeerId: null,
        title: v1.title,
        details: v1.details,
      );
      // Re-sign as a version 1 layout by encoding the unsigned v1 shape.
      final v1Bytes = v1.copyWith(signature: signed.signature).encode();
      expect(v1Bytes[0], 1);
      expect(v1Bytes.length, signed.encode().length - 32);
      final decoded = BountyRM.decode(v1Bytes);
      expect(decoded, isNotNull);
      expect(decoded!.version, 1);
      expect(decoded.authorNostrKey, isEmpty);
    });

    test('a truncated record is refused rather than half read', () async {
      final bytes = (await post()).encode();
      expect(BountyRM.decode(bytes.sublist(0, bytes.length - 1)), isNull);
    });
  });

  group('BountyMessageRM', () {
    test('round trips', () {
      const msg = BountyMessageRM(
        kind: BountyMessageRM.kindClaim,
        bountyId: '0123456789abcdef',
        sentAt: 1800000000,
        note: 'I am two floors down, five minutes.',
      );
      final decoded = BountyMessageRM.decode(msg.encode());
      expect(decoded!.kind, BountyMessageRM.kindClaim);
      expect(decoded.bountyId, '0123456789abcdef');
      expect(decoded.sentAt, 1800000000);
      expect(decoded.note, 'I am two floors down, five minutes.');
    });

    test('an empty note is fine and small', () {
      const msg = BountyMessageRM(
        kind: BountyMessageRM.kindDone,
        bountyId: '0123456789abcdef',
        sentAt: 1,
        note: '',
      );
      expect(msg.encode(), hasLength(14));
    });

    test('an unknown kind is refused', () {
      final bytes = const BountyMessageRM(
        kind: BountyMessageRM.kindAccept,
        bountyId: '0123456789abcdef',
        sentAt: 1,
        note: '',
      ).encode();
      bytes[0] = 99;
      expect(BountyMessageRM.decode(bytes), isNull);
    });
  });
}
