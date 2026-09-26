import 'package:flutter_test/flutter_test.dart';
import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/mesh_transport/mesh_transport.dart';
import 'package:radius/local_storage/local_storage.dart';
import 'package:radius/repositories/identity_repository/identity_repository.dart';
import 'package:radius/repositories/identity_repository/src/identity_local_storage.dart';

class _MemoryVault implements SeedVault {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String v) async => value = v;

  @override
  Future<void> delete() async => value = null;
}

class _MemoryPrefs extends IdentityLocalStorage {
  _MemoryPrefs()
    : super(keyValueStorage: KeyValueStorage(initialize: (_) async {}));

  bool onboarded = false;
  int reads = 0;

  @override
  Future<bool> getOnboarded() async {
    reads++;
    return onboarded;
  }

  @override
  Future<void> setOnboarded() async => onboarded = true;

  int resets = 0;

  @override
  Future<void> reset() async {
    onboarded = false;
    resets++;
  }
}

class _BrokenVault implements SeedVault {
  @override
  Future<String?> read() => throw StateError('keystore locked');

  @override
  Future<void> write(String v) => throw StateError('keystore locked');

  @override
  Future<void> delete() => throw StateError('keystore locked');
}

void main() {
  test('a first launch creates an identity', () async {
    final repository = IdentityRepository(
      loadedIdentity: IdentityStore(vault: _MemoryVault()).loadOrCreate(),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      localStorage: _MemoryPrefs(),
    );

    final identity = await repository.getIdentity();

    expect(identity.origin, IdentityOrigin.created);
    expect(identity.peerId, hasLength(16));
    expect(identity.shortId, hasLength(4));
    expect(identity.npub, startsWith('npub1'));
  });

  test('the same identity comes back every time', () async {
    // One keystore read and one key derivation per launch, not per screen.
    final repository = IdentityRepository(
      loadedIdentity: IdentityStore(vault: _MemoryVault()).loadOrCreate(),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      localStorage: _MemoryPrefs(),
    );

    final first = await repository.getIdentity();
    final second = await repository.getIdentity();

    expect(identical(first, second), isTrue);
  });

  test('a vault that cannot be read is a domain exception', () async {
    final repository = IdentityRepository(
      loadedIdentity: IdentityStore(vault: _BrokenVault()).loadOrCreate(),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      localStorage: _MemoryPrefs(),
    );

    expect(repository.getIdentity(), throwsA(isA<IdentityLoadException>()));
  });

  test('onboarding is read from disk once and remembered', () async {
    final prefs = _MemoryPrefs();
    final repository = IdentityRepository(
      loadedIdentity: IdentityStore(vault: _MemoryVault()).loadOrCreate(),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      localStorage: prefs,
    );

    expect(await repository.hasOnboarded(), isFalse);
    expect(await repository.hasOnboarded(), isFalse);
    expect(prefs.reads, 1);

    await repository.markOnboarded();
    expect(await repository.hasOnboarded(), isTrue);
    expect(prefs.onboarded, isTrue);
  });

  test('forgetting erases the seed and resets the phone', () async {
    final vault = _MemoryVault();
    final store = IdentityStore(vault: vault);
    final prefs = _MemoryPrefs()..onboarded = true;
    final repo = IdentityRepository(
      loadedIdentity: store.loadOrCreate(),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      identityStore: store,
      localStorage: prefs,
    );
    await repo.getIdentity();
    expect(vault.value, isNotNull);

    await repo.forgetIdentity();

    expect(vault.value, isNull);
    expect(prefs.resets, 1);
    expect(await repo.hasOnboarded(), isFalse);
  });

  test('forgetting without a store is refused, not silently skipped', () {
    final store = IdentityStore(vault: _MemoryVault());
    final repo = IdentityRepository(
      loadedIdentity: store.loadOrCreate(),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      localStorage: _MemoryPrefs(),
    );
    expect(repo.forgetIdentity(), throwsA(isA<IdentityForgetException>()));
  });

  test('a vault that will not erase keeps the identity', () async {
    // Loaded fine earlier in the session; the keystore refuses only now.
    final prefs = _MemoryPrefs()..onboarded = true;
    final repo = IdentityRepository(
      loadedIdentity: IdentityStore(vault: _MemoryVault()).loadOrCreate(),
      keyValueStorage: KeyValueStorage(initialize: (_) async {}),
      identityStore: IdentityStore(vault: _BrokenVault()),
      localStorage: prefs,
    );
    await expectLater(
      repo.forgetIdentity(),
      throwsA(isA<IdentityForgetException>()),
    );
    expect(prefs.onboarded, isTrue);
  });
}
