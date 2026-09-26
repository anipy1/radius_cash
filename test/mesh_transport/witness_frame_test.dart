import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radius/mesh_transport/src/ble/frame.dart';
import 'package:radius/mesh_transport/src/ble/sealed_payload.dart';

/// The radio-only rule, and the plumbing around it.
///
/// A witness signature is worth something only because the witness was
/// physically near the phone that said it finished. Radio range is the only
/// thing that establishes that. Anything off a Nostr relay could have come
/// from the other side of the planet, so honouring a relayed request would
/// make the whole feature decorative. These are the tests that hold that
/// line.
void main() {
  const bountyId = '0011223344556677';
  const claimant = '8899aabbccddeeff';

  group('the radio-only rule', () {
    test('a request that arrived over the internet is refused', () {
      final frame = Frame.witnessRequest(
        bountyId: bountyId,
        claimantPeerId: claimant,
      );
      final decoded = Frame.decode(frame.encode())!;

      // The very same bytes are fine off the radio and worthless off a relay.
      // Nothing about the frame differs; only where it came from.
      expect(
        WitnessRequest.parse(decoded, fromInternet: false),
        isNotNull,
        reason: 'a request heard on the radio is honoured',
      );
      expect(
        WitnessRequest.parse(decoded, fromInternet: true),
        isNull,
        reason: 'the same request off a relay proves no proximity',
      );
    });

    test('provenance is the only thing that decides it', () {
      // Not a property of the content: no field a sender controls can turn a
      // relayed request into a radio one.
      final frame = Frame.decode(
        Frame.witnessRequest(
          bountyId: bountyId,
          claimantPeerId: claimant,
          ttl: 1,
        ).encode(),
      )!;
      expect(WitnessRequest.parse(frame, fromInternet: true), isNull);
    });
  });

  group('the request frame', () {
    test('round-trips the bounty and the claimant', () {
      final frame = Frame.decode(
        Frame.witnessRequest(
          bountyId: bountyId,
          claimantPeerId: claimant,
        ).encode(),
      )!;
      final request = WitnessRequest.parse(frame, fromInternet: false)!;

      expect(frame.isWitness, isTrue);
      expect(request.bountyId, bountyId);
      expect(request.claimantPeerId, claimant);
    });

    test('is one frame, so it is never fragmented', () {
      // A fragmented request loses its provenance: the assembler does not
      // carry which pipe the pieces came in on, so MeshLink drops rebuilt
      // ones. This guards against a future field pushing it over the line.
      final bytes = Frame.witnessRequest(
        bountyId: bountyId,
        claimantPeerId: claimant,
      ).encode();
      expect(bytes.length, lessThanOrEqualTo(Frame.meshMtu));
    });

    test('a stale build sees it as relayable, not text', () {
      final frame = Frame.witnessRequest(
        bountyId: bountyId,
        claimantPeerId: claimant,
      );
      expect(frame.type, Frame.typeWitness);
      expect(frame.isReadableText, isFalse);
    });

    test('a truncated request is refused', () {
      final frame = Frame.witnessRequest(
        bountyId: bountyId,
        claimantPeerId: claimant,
      );
      final short = Frame(
        envelopeVer: Frame.envelopeVersion,
        ttl: frame.ttl,
        msgId: frame.msgId,
        payload: Uint8List.sublistView(frame.payload, 0, 8),
      );
      expect(WitnessRequest.parse(short, fromInternet: false), isNull);
    });

    test('an unknown record version is refused', () {
      final frame = Frame.witnessRequest(
        bountyId: bountyId,
        claimantPeerId: claimant,
      );
      final payload = Uint8List.fromList(frame.payload)..[2] = 99;
      final bumped = Frame(
        envelopeVer: Frame.envelopeVersion,
        ttl: frame.ttl,
        msgId: frame.msgId,
        payload: payload,
      );
      expect(WitnessRequest.parse(bumped, fromInternet: false), isNull);
    });

    test('a frame of another type is not a witness request', () {
      final bounty = Frame.bounty(Uint8List(10));
      expect(WitnessRequest.parse(bounty, fromInternet: false), isNull);
    });
  });

  test('a sealed witness is its own kind', () {
    final body = Uint8List.fromList([9, 8, 7]);
    final payload = SealedPayload.parse(SealedPayload.encodeWitness(body))!;

    expect(payload.kind, SealedKind.witness);
    expect(payload.body, body);
    // The four codes have to stay distinct or an older build renders one kind
    // as another.
    expect(SealedKind.values.map((k) => k.code).toSet(), {1, 2, 3, 4});
  });
}
