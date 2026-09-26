import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radius/mesh_transport/src/ble/frame.dart';
import 'package:radius/mesh_transport/src/ble/sealed_payload.dart';

void main() {
  test('a bounty frame carries its record bytes untouched', () {
    final record = Uint8List.fromList(List.generate(300, (i) => i % 256));
    final frame = Frame.bounty(record);
    final decoded = Frame.decode(frame.encode())!;

    expect(decoded.isBounty, isTrue);
    expect(decoded.isReadableText, isFalse);
    expect(decoded.body, record);
  });

  test('a stale build sees a bounty as relayable, not text', () {
    final frame = Frame.bounty(Uint8List(5));
    expect(frame.type, Frame.typeBounty);
    expect(frame.isReadableText, isFalse);
  });

  test('a sealed bounty message is its own kind', () {
    final body = Uint8List.fromList([1, 2, 3]);
    final payload = SealedPayload.parse(SealedPayload.encodeBounty(body))!;
    expect(payload.kind, SealedKind.bounty);
    expect(payload.body, body);
  });
}
