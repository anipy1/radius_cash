import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:radius/mesh_transport/mesh_transport.dart';

/// The real one: Keychain on darwin, and on Android a hardware-backed key
/// wrapping the value.
class SecureSeedVault implements SeedVault {
  const SecureSeedVault();

  /// Versioned so a future change to what is stored can be told apart from a
  /// corrupt value rather than guessed at.
  static const key = 'radius.identity.seed.v1';

  /// Readable once the device has been unlocked at least once since boot,
  /// including while it is locked afterwards.
  ///
  /// The default is stricter, readable only while unlocked, which would stop
  /// the mesh dead the moment the screen locks. That is precisely when a mesh
  /// app should still be working.
  static const _darwin = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: key, iOptions: _darwin);

  @override
  Future<void> write(String value) =>
      _storage.write(key: key, value: value, iOptions: _darwin);

  @override
  Future<void> delete() => _storage.delete(key: key, iOptions: _darwin);
}
