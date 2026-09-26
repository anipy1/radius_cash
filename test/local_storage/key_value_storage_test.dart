import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:radius/local_storage/local_storage.dart';

void main() {
  late Directory dir;
  late KeyValueStorage storage;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('radius_kv_');
    Hive.init(dir.path);
    storage = KeyValueStorage(hive: Hive, initialize: (_) async {});
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  BountyCM bounty(String id) => BountyCM(
    id: id,
    authorPeerId: '00' * 8,
    authorSigningKey: Uint8List.fromList(List.filled(32, 7)),
    record: Uint8List.fromList([1, 2, 3]),
    title: 'title',
    details: 'details',
    amountCents: 1200,
    createdAt: 1,
    expiresAt: 2,
    updatedAt: 1,
    status: 1,
    claimantPeerId: null,
  );

  test('a bounty round trips, byte fields included', () async {
    final box = await storage.bountiesBox;
    await box.put('x', bounty('x'));
    final back = box.get('x')!;
    expect(back.title, 'title');
    expect(back.authorSigningKey, List.filled(32, 7));
    expect(back.record, [1, 2, 3]);
    expect(back.claimantPeerId, isNull);
  });

  test('a claim round trips', () async {
    final box = await storage.claimsBox;
    final claim = ClaimCM(
      bountyId: 'x',
      claimantPeerId: 'ff' * 8,
      note: 'soon',
      sentAt: 5,
      status: ClaimCM.statusPending,
    );
    await box.put(claim.key, claim);
    expect(box.get('x:${'ff' * 8}')!.note, 'soon');
  });

  test('asking for a box twice is the same box', () async {
    expect(
      identical(await storage.bountiesBox, await storage.bountiesBox),
      isTrue,
    );
  });

  test('clearCaches empties all three', () async {
    await (await storage.bountiesBox).put('x', bounty('x'));
    await (await storage.witnessesBox).put(
      'x:y',
      WitnessCM(
        bountyId: 'x',
        claimantPeerId: 'y',
        witnessPeerId: 'z',
        record: Uint8List.fromList([1, 2, 3]),
        at: 1,
      ),
    );
    await storage.clearCaches();
    expect((await storage.bountiesBox).isEmpty, isTrue);
    expect((await storage.claimsBox).isEmpty, isTrue);
    expect((await storage.witnessesBox).isEmpty, isTrue);
  });

  test('a witness round trips, signed bytes included', () async {
    final record = Uint8List.fromList(List.generate(157, (i) => i % 256));
    final witness = WitnessCM(
      bountyId: 'b',
      claimantPeerId: 'c',
      witnessPeerId: 'w',
      record: record,
      at: 1790000000,
      mine: true,
    );
    await (await storage.witnessesBox).put(witness.key, witness);

    final read = (await storage.witnessesBox).get('b:w')!;
    expect(read.record, record);
    expect(read.mine, isTrue);
    expect(read.at, 1790000000);
    expect(read.claimantPeerId, 'c');
  });
}
