import 'package:radius/domain_models/domain_models.dart';
import 'package:radius/local_storage/local_storage.dart';

/// The identity repository's few preferences, in the settings box.
class IdentityLocalStorage {
  const IdentityLocalStorage({required this.keyValueStorage});

  final KeyValueStorage keyValueStorage;

  static const _onboardedKey = 'onboarded';

  Future<bool> getOnboarded() => _guard(() async {
    final box = await keyValueStorage.settingsBox;
    return box.get(_onboardedKey) == true;
  });

  Future<void> setOnboarded() => _guard(() async {
    final box = await keyValueStorage.settingsBox;
    await box.put(_onboardedKey, true);
  });

  /// Back to a phone that has never run the app: no onboarding flag, no
  /// cached bounties or claims.
  Future<void> reset() => _guard(() async {
    final box = await keyValueStorage.settingsBox;
    await box.delete(_onboardedKey);
    await keyValueStorage.clearCaches();
  });

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (_) {
      throw PreferencesException();
    }
  }
}
