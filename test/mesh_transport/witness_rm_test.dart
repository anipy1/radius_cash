import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radius/mesh_transport/src/bounty/witness_rm.dart';
import 'package:radius/mesh_transport/src/identity/node_identity.dart';

void main() {
  const bountyId = '0011223344556677';
  late NodeIdentity witness;
  late NodeIdentity claimant;
  late NodeIdentity stranger;

  setUpAll(() async {
    witness = await NodeIdentity.fromSeed(
      Uint8List.fromList(List.filled(32, 1)),
    );
    claimant = await NodeIdentity.fromSeed(
      Uint8List.fromList(List.filled(32, 2)),
    );
    stranger = await NodeIdentity.fromSeed(
      Uint8List.fromList(List.filled(32, 3)),
    );
  });

  Future<WitnessRM> signed({NodeIdentity? by, int at = 1790000000}) {
    final id = by ?? witness;
    return WitnessRM.sign(
      bountyId: bountyId,
      claimantPeerId: claimant.peerId,
      witnessPeerId: id.peerId,
      signingKeyPair: id.signingKeyPair,
      signingPublicKey: id.signingPublicKey,
      noisePublicKey: id.noisePublicKey,
      at: at,
    );
  }

  group('encode and decode', () {
    test('a signed witness verifies and round-trips', () async {
      final rm = await signed();
      final bytes = rm.encode();
      final decoded = WitnessRM.decode(bytes)!;

      expect(bytes.length, WitnessRM.recordLength);
      expect(bytes.length, 157);
      expect(decoded.version, WitnessRM.currentVersion);
      expect(decoded.bountyId, bountyId);
      expect(decoded.claimantPeerId, claimant.peerId);
      expect(decoded.witnessPeerId, witness.peerId);
      expect(decoded.witnessNoiseKey, witness.noisePublicKey);
      expect(decoded.witnessSigningKey, witness.signingPublicKey);
      expect(decoded.at, 1790000000);
      expect(decoded.signature, rm.signature);
      expect(await decoded.verify(), isTrue);
    });

    test('a record of the wrong length decodes to null', () async {
      final bytes = (await signed()).encode();
      expect(WitnessRM.decode(Uint8List.sublistView(bytes, 0, 156)), isNull);
      expect(
        WitnessRM.decode(Uint8List.fromList([...bytes, 0])),
        isNull,
        reason: 'every field is fixed width, so there is no trailing room',
      );
    });

    test('an unknown version decodes to null', () async {
      final bytes = (await signed()).encode()..[0] = 2;
      expect(WitnessRM.decode(bytes), isNull);
    });
  });

  group('tamper rejection', () {
    test('a changed bounty id does not verify', () async {
      final bytes = (await signed()).encode();
      bytes[1] ^= 0xFF; // first byte of the bounty id
      expect(await WitnessRM.decode(bytes)!.verify(), isFalse);
    });

    test('a changed timestamp does not verify', () async {
      final rm = await signed();
      final bytes = rm.encode();
      // The 4 timestamp bytes sit immediately before the signature.
      final at = WitnessRM.recordLength - WitnessRM.signatureLength - 4;
      bytes[at] ^= 0xFF;
      expect(await WitnessRM.decode(bytes)!.verify(), isFalse);
    });

    test('a changed claimant does not verify', () async {
      final bytes = (await signed()).encode();
      bytes[1 + WitnessRM.idLength] ^= 0xFF;
      expect(await WitnessRM.decode(bytes)!.verify(), isFalse);
    });

    test('a mangled signature does not verify', () async {
      final bytes = (await signed()).encode();
      bytes[WitnessRM.recordLength - 1] ^= 0xFF;
      expect(await WitnessRM.decode(bytes)!.verify(), isFalse);
    });

    test('a signature by the wrong key does not verify', () async {
      // Signed by the witness, but carrying a stranger's signing key.
      final rm = await signed();
      final forged = WitnessRM(
        version: rm.version,
        bountyId: rm.bountyId,
        claimantPeerId: rm.claimantPeerId,
        witnessPeerId: rm.witnessPeerId,
        witnessNoiseKey: rm.witnessNoiseKey,
        witnessSigningKey: stranger.signingPublicKey,
        at: rm.at,
        signature: rm.signature,
      );
      expect(await forged.verify(), isFalse);
    });
  });

  group('the peer id binding', () {
    test('a peer id really is the hash of its noise key', () async {
      final rm = await signed();
      expect(await rm.bindsToItsPeerId(), isTrue);
      // The same construction NodeIdentity uses, so a witness id can be
      // compared against a bounty's author and claimant.
      expect(rm.witnessPeerId, witness.peerId);
    });

    test(
      'a key that does not hash to the claimed peer id is refused',
      () async {
        // Everything signed correctly, but the record names somebody else's
        // peer id. Without the binding this would pass: the signature is over
        // the body, and the body is what it says it is.
        final rm = await WitnessRM.sign(
          bountyId: bountyId,
          claimantPeerId: claimant.peerId,
          witnessPeerId: stranger.peerId, // not witness.peerId
          signingKeyPair: witness.signingKeyPair,
          signingPublicKey: witness.signingPublicKey,
          noisePublicKey: witness.noisePublicKey,
          at: 1790000000,
        );

        expect(await rm.bindsToItsPeerId(), isFalse);
        expect(
          await rm.verify(),
          isFalse,
          reason: 'verify refuses a record whose peer id is not its own',
        );
      },
    );

    test('swapping in another noise key breaks the binding', () async {
      final rm = await signed();
      final swapped = WitnessRM(
        version: rm.version,
        bountyId: rm.bountyId,
        claimantPeerId: rm.claimantPeerId,
        witnessPeerId: rm.witnessPeerId,
        witnessNoiseKey: stranger.noisePublicKey,
        witnessSigningKey: rm.witnessSigningKey,
        at: rm.at,
        signature: rm.signature,
      );
      expect(await swapped.bindsToItsPeerId(), isFalse);
      expect(await swapped.verify(), isFalse);
    });

    test('a short noise key is refused rather than hashed', () async {
      final rm = await signed();
      final stunted = WitnessRM(
        version: rm.version,
        bountyId: rm.bountyId,
        claimantPeerId: rm.claimantPeerId,
        witnessPeerId: rm.witnessPeerId,
        witnessNoiseKey: Uint8List(4),
        witnessSigningKey: rm.witnessSigningKey,
        at: rm.at,
        signature: rm.signature,
      );
      expect(await stunted.bindsToItsPeerId(), isFalse);
      expect(await stunted.verify(), isFalse);
    });
  });

  test('two witnesses to the same completion are distinct records', () async {
    final mine = await signed();
    final theirs = await signed(by: stranger);

    expect(mine.witnessPeerId, isNot(theirs.witnessPeerId));
    expect(mine.encode(), isNot(theirs.encode()));
    expect(await mine.verify(), isTrue);
    expect(await theirs.verify(), isTrue);
  });
}
