import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:radius/repositories/bounty_repository/src/mappers/mappers.dart';

void main() {
  const me = '00112233aabbccdd';
  const other = 'ffeeddcc00112233';

  final rm = BountyRM(
    version: 1,
    id: '0123456789abcdef',
    authorPeerId: other,
    authorSigningKey: Uint8List(32),
    authorNostrKey: Uint8List(0),
    createdAt: 1800000000,
    expiresAt: 1800003600,
    updatedAt: 1800000000,
    amountCents: 2500,
    status: BountyRM.statusClaimed,
    claimantPeerId: me,
    title: 'Carry',
    details: 'Now',
    geohash: 'ud9d5',
    signature: Uint8List(64),
  );

  group('remote to cache', () {
    test('keeps every field and the raw record', () {
      final record = Uint8List.fromList([9, 9, 9]);
      final cm = rm.toCacheModel(record: record);
      expect(cm.id, rm.id);
      expect(cm.authorPeerId, other);
      expect(cm.record, record);
      expect(cm.status, BountyRM.statusClaimed);
      expect(cm.claimantPeerId, me);
      expect(cm.amountCents, 2500);
    });

    test('a claim message becomes a pending claim from its sender', () {
      const msg = BountyMessageRM(
        kind: BountyMessageRM.kindClaim,
        bountyId: '0123456789abcdef',
        sentAt: 7,
        note: 'me',
      );
      final cm = msg.toClaimCacheModel(from: other);
      expect(cm.claimantPeerId, other);
      expect(cm.status, ClaimCM.statusPending);
      expect(cm.note, 'me');
    });
  });

  group('cache to domain', () {
    test('a bounty gets labels, times and ownership', () {
      final bounty = rm
          .toCacheModel(record: Uint8List(0))
          .toDomainModel(myPeerId: me);
      expect(bounty.isMine, isFalse);
      expect(bounty.authorLabel, MeshLink.labelOf(other));
      expect(bounty.claimantLabel, MeshLink.labelOf(me));
      expect(bounty.status, BountyStatus.claimed);
      expect(bounty.createdAt, DateTime.utc(2027, 1, 15, 8, 0, 0));
      expect(
        bounty.expiresAt.difference(bounty.createdAt),
        const Duration(hours: 1),
      );
    });

    test('isMine follows the author', () {
      final bounty = rm
          .toCacheModel(record: Uint8List(0))
          .toDomainModel(myPeerId: other);
      expect(bounty.isMine, isTrue);
    });

    test('every status code maps, and an unknown one throws', () {
      expect(BountyRM.statusOpen.toBountyStatus(), BountyStatus.open);
      expect(BountyRM.statusCancelled.toBountyStatus(), BountyStatus.cancelled);
      expect(() => 9.toBountyStatus(), throwsFormatException);
      expect(ClaimCM.statusDone.toClaimStatus(), ClaimStatus.done);
      expect(() => 0.toClaimStatus(), throwsFormatException);
    });

    test('a claim knows whether I made it', () {
      const cm = ClaimCM(
        bountyId: 'x',
        claimantPeerId: me,
        note: '',
        sentAt: 1,
        status: ClaimCM.statusAccepted,
      );
      expect(cm.toDomainModel(myPeerId: me).isMine, isTrue);
      expect(cm.toDomainModel(myPeerId: other).isMine, isFalse);
      expect(cm.toDomainModel(myPeerId: me).status, ClaimStatus.accepted);
    });

    test('a witness keeps its signed bytes and knows whose it is', () async {
      final identity = await NodeIdentity.fromSeed(
        Uint8List.fromList(List.filled(32, 4)),
      );
      final rm = await WitnessRM.sign(
        bountyId: '0123456789abcdef',
        claimantPeerId: other,
        witnessPeerId: identity.peerId,
        signingKeyPair: identity.signingKeyPair,
        signingPublicKey: identity.signingPublicKey,
        noisePublicKey: identity.noisePublicKey,
        at: 1790000000,
      );
      final bytes = rm.encode();
      final cm = rm.toCacheModel(record: bytes, mine: true);

      // The exact bytes, or the signature stops verifying for whoever we
      // forward it to.
      expect(cm.record, bytes);
      expect(cm.mine, isTrue);
      expect(cm.key, '0123456789abcdef:${identity.peerId}');

      final domain = cm.toDomainModel(myPeerId: identity.peerId);
      expect(domain.isMine, isTrue);
      expect(domain.witnessId, identity.peerId);
      expect(domain.claimantId, other);
      expect(domain.witnessLabel, MeshLink.labelOf(identity.peerId));
      expect(
        domain.at,
        DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000, isUtc: true),
      );
      expect(cm.toDomainModel(myPeerId: me).isMine, isFalse);
    });
  });
}
