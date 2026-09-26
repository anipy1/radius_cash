import 'package:meta/meta.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';

import 'identity_local_storage.dart';
import 'mappers/mappers.dart';

/// Who this node is.
///
/// A Future rather than a stream on purpose. The identity is fixed for the
/// life of the process: the radio is bound to it at construction and the node
/// id goes out in the first advertisement, so there is nothing to react to.
class IdentityRepository {
  IdentityRepository({
    required Future<LoadedIdentity> loadedIdentity,
    required KeyValueStorage keyValueStorage,
    IdentityStore? identityStore,
    @visibleForTesting IdentityLocalStorage? localStorage,
  }) : _loaded = loadedIdentity,
       _store = identityStore,
       _storage =
           localStorage ??
           IdentityLocalStorage(keyValueStorage: keyValueStorage);

  final IdentityLocalStorage _storage;

  /// Where the seed lives, for forgetting it. Optional because a host that
  /// cannot forget (a test, a preview) still has an identity to show.
  final IdentityStore? _store;
  bool? _onboarded;

  /// Shared with the mesh repository, so the seed is read from secure storage
  /// once per launch and both see the same identity.
  final Future<LoadedIdentity> _loaded;

  late final Future<Identity> _identity = _load();

  Future<Identity> getIdentity() => _identity;

  /// Whether this person has been through the first-launch screens.
  ///
  /// Read from disk once; afterwards the answer is remembered, because the
  /// router asks on every navigation.
  Future<bool> hasOnboarded() async =>
      _onboarded ??= await _storage.getOnboarded();

  Future<void> markOnboarded() async {
    await _storage.setOnboarded();
    _onboarded = true;
  }

  /// Erases the seed and everything derived from or attached to it: the
  /// keys, the cached bounties and claims, the onboarding flag.
  ///
  /// The running mesh still holds the old identity in memory; the caller
  /// stops it first and the next launch starts as a new phone. There is no
  /// undo, which is the point.
  Future<void> forgetIdentity() async {
    final store = _store;
    if (store == null) throw IdentityForgetException();
    try {
      await store.erase();
    } catch (_) {
      throw IdentityForgetException();
    }
    await _storage.reset();
    _onboarded = false;
  }

  Future<Identity> _load() async {
    try {
      final loaded = await _loaded;
      // Derived from the same seed as the mesh keys, so there is one secret on
      // the device and the Nostr address needs nothing extra stored.
      final nostr = await NostrIdentity.fromSeed(loaded.identity.seed);
      return loaded.toDomainModel(nostr: nostr);
    } catch (_) {
      throw IdentityLoadException();
    }
  }
}
