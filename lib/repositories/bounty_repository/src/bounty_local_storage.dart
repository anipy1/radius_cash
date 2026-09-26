import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';

/// The bounty repository's view of the cache. Everything here is a box
/// operation; nothing here knows what a signature is.
///
/// This is also where Hive stops: whatever it throws, a full disk, a box that
/// would not open, a corrupt file, leaves here as [BountyCacheException].
class BountyLocalStorage {
  const BountyLocalStorage({required this.keyValueStorage});

  final KeyValueStorage keyValueStorage;

  Future<List<BountyCM>> getBounties() =>
      _guard(() async => (await keyValueStorage.bountiesBox).values.toList());

  Future<BountyCM?> getBounty(String id) =>
      _guard(() async => (await keyValueStorage.bountiesBox).get(id));

  Future<void> upsertBounty(BountyCM bounty) => _guard(
    () async => (await keyValueStorage.bountiesBox).put(bounty.id, bounty),
  );

  Future<List<ClaimCM>> getClaims() =>
      _guard(() async => (await keyValueStorage.claimsBox).values.toList());

  Future<ClaimCM?> getClaim(String bountyId, String claimantPeerId) => _guard(
    () async => (await keyValueStorage.claimsBox).get(
      ClaimCM.keyFor(bountyId, claimantPeerId),
    ),
  );

  Future<void> upsertClaim(ClaimCM claim) => _guard(
    () async => (await keyValueStorage.claimsBox).put(claim.key, claim),
  );

  Future<void> deleteClaim(String bountyId, String claimantPeerId) => _guard(
    () async => (await keyValueStorage.claimsBox).delete(
      ClaimCM.keyFor(bountyId, claimantPeerId),
    ),
  );

  Future<List<WitnessCM>> getWitnesses() =>
      _guard(() async => (await keyValueStorage.witnessesBox).values.toList());

  Future<WitnessCM?> getWitness(String bountyId, String witnessPeerId) =>
      _guard(
        () async => (await keyValueStorage.witnessesBox).get(
          WitnessCM.keyFor(bountyId, witnessPeerId),
        ),
      );

  Future<void> upsertWitness(WitnessCM witness) => _guard(
    () async => (await keyValueStorage.witnessesBox).put(witness.key, witness),
  );

  Future<void> clear() => _guard(keyValueStorage.clearCaches);

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (_) {
      throw BountyCacheException();
    }
  }
}
