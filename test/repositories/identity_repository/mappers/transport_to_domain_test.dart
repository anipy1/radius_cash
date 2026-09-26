import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:radius/repositories/identity_repository/src/mappers/mappers.dart';

void main() {
  final seed = Uint8List.fromList(List.generate(32, (i) => i));

  test('every source maps to its origin', () {
    expect(IdentitySource.restored.toDomainModel(), IdentityOrigin.restored);
    expect(IdentitySource.created.toDomainModel(), IdentityOrigin.created);
    expect(IdentitySource.replaced.toDomainModel(), IdentityOrigin.replaced);
  });

  test('a loaded identity keeps its ids and gains its npub', () async {
    final node = await NodeIdentity.fromSeed(seed);
    final nostr = await NostrIdentity.fromSeed(seed);

    final identity = LoadedIdentity(
      node,
      IdentitySource.created,
    ).toDomainModel(nostr: nostr);

    expect(identity.peerId, node.peerId);
    expect(identity.shortId, node.shortId);
    expect(identity.npub, nostr.npub);
    expect(identity.npub, startsWith('npub1'));
    expect(identity.origin, IdentityOrigin.created);
  });
}
